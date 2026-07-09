#import "./include/just_audio/DarwinEqualizer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <math.h>
#import <stdbool.h>
#import <stdatomic.h>
#import <stdlib.h>

#define DARWIN_EQUALIZER_BAND_COUNT 5
#define DARWIN_EQUALIZER_MIN_DECIBELS -12.0
#define DARWIN_EQUALIZER_MAX_DECIBELS 12.0
#define DARWIN_EQUALIZER_GAIN_SCALE 100.0

static const double DarwinEqualizerLowerFrequencies[DARWIN_EQUALIZER_BAND_COUNT] = {
    20.0,
    250.0,
    500.0,
    2000.0,
    6000.0,
};

static const double DarwinEqualizerUpperFrequencies[DARWIN_EQUALIZER_BAND_COUNT] = {
    250.0,
    500.0,
    2000.0,
    6000.0,
    20000.0,
};

static const double DarwinEqualizerCenterFrequencies[DARWIN_EQUALIZER_BAND_COUNT] = {
    125.0,
    375.0,
    1000.0,
    4000.0,
    10000.0,
};

typedef struct DarwinEqualizerTapState {
    atomic_bool enabled;
    atomic_int gainsCentibels[DARWIN_EQUALIZER_BAND_COUNT];
} DarwinEqualizerTapState;

typedef struct DarwinEqualizerTapContext {
    void *owner;
    DarwinEqualizerTapState *state;
    AudioFormatFlags formatFlags;
    UInt32 bitsPerChannel;
} DarwinEqualizerTapContext;

@interface DarwinEqualizer ()
- (DarwinEqualizerTapState *)tapState;
@end

static double DarwinEqualizerClampDouble(double value, double minValue, double maxValue) {
    return fmin(fmax(value, minValue), maxValue);
}

static Float32 DarwinEqualizerClampFloat32(Float32 value, Float32 minValue, Float32 maxValue) {
    return fminf(fmaxf(value, minValue), maxValue);
}

static SInt16 DarwinEqualizerClampSInt16(double value) {
    if (value > 32767.0) return 32767;
    if (value < -32768.0) return -32768;
    return (SInt16)lrint(value);
}

static float DarwinEqualizerAggregateLinearGain(DarwinEqualizerTapState *state) {
    int totalCentibels = 0;
    for (int i = 0; i < DARWIN_EQUALIZER_BAND_COUNT; i++) {
        totalCentibels += atomic_load_explicit(&state->gainsCentibels[i], memory_order_relaxed);
    }
    double averageDecibels = ((double)totalCentibels / DARWIN_EQUALIZER_BAND_COUNT) / DARWIN_EQUALIZER_GAIN_SCALE;
    averageDecibels = DarwinEqualizerClampDouble(averageDecibels, DARWIN_EQUALIZER_MIN_DECIBELS, DARWIN_EQUALIZER_MAX_DECIBELS);
    return (float)pow(10.0, averageDecibels / 20.0);
}

static void DarwinEqualizerTapInit(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    DarwinEqualizer *equalizer = (__bridge DarwinEqualizer *)clientInfo;
    DarwinEqualizerTapContext *context = calloc(1, sizeof(DarwinEqualizerTapContext));
    if (!context) {
        *tapStorageOut = NULL;
        return;
    }
    context->owner = (__bridge_retained void *)equalizer;
    context->state = [equalizer tapState];
    *tapStorageOut = context;
}

static void DarwinEqualizerTapFinalize(MTAudioProcessingTapRef tap) {
    DarwinEqualizerTapContext *context = (DarwinEqualizerTapContext *)MTAudioProcessingTapGetStorage(tap);
    if (!context) return;
    if (context->owner) {
        (void)CFBridgingRelease(context->owner);
        context->owner = NULL;
    }
    free(context);
}

static void DarwinEqualizerTapPrepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat) {
    DarwinEqualizerTapContext *context = (DarwinEqualizerTapContext *)MTAudioProcessingTapGetStorage(tap);
    if (!context || !processingFormat) return;
    context->formatFlags = processingFormat->mFormatFlags;
    context->bitsPerChannel = processingFormat->mBitsPerChannel;
}

static void DarwinEqualizerTapUnprepare(MTAudioProcessingTapRef tap) {
}

static void DarwinEqualizerApplyFloat32Gain(AudioBufferList *bufferList, float linearGain) {
    for (UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; bufferIndex++) {
        AudioBuffer *buffer = &bufferList->mBuffers[bufferIndex];
        Float32 *samples = (Float32 *)buffer->mData;
        if (!samples) continue;
        UInt32 sampleCount = buffer->mDataByteSize / sizeof(Float32);
        for (UInt32 sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
            samples[sampleIndex] = DarwinEqualizerClampFloat32(samples[sampleIndex] * linearGain, -1.0f, 1.0f);
        }
    }
}

static void DarwinEqualizerApplySInt16Gain(AudioBufferList *bufferList, float linearGain) {
    for (UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; bufferIndex++) {
        AudioBuffer *buffer = &bufferList->mBuffers[bufferIndex];
        SInt16 *samples = (SInt16 *)buffer->mData;
        if (!samples) continue;
        UInt32 sampleCount = buffer->mDataByteSize / sizeof(SInt16);
        for (UInt32 sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
            samples[sampleIndex] = DarwinEqualizerClampSInt16((double)samples[sampleIndex] * linearGain);
        }
    }
}

static void DarwinEqualizerTapProcess(
    MTAudioProcessingTapRef tap,
    CMItemCount numberFrames,
    MTAudioProcessingTapFlags flags,
    AudioBufferList *bufferListInOut,
    CMItemCount *numberFramesOut,
    MTAudioProcessingTapFlags *flagsOut) {
    OSStatus status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, NULL, numberFramesOut);
    if (status != noErr) {
        if (numberFramesOut) {
            *numberFramesOut = 0;
        }
        return;
    }

    DarwinEqualizerTapContext *context = (DarwinEqualizerTapContext *)MTAudioProcessingTapGetStorage(tap);
    if (!context || !context->state) return;
    if (!atomic_load_explicit(&context->state->enabled, memory_order_relaxed)) return;

    float linearGain = DarwinEqualizerAggregateLinearGain(context->state);
    if (fabsf(linearGain - 1.0f) < 0.0001f) return;

    BOOL isFloat = (context->formatFlags & kAudioFormatFlagIsFloat) != 0;
    BOOL isSignedInteger = (context->formatFlags & kAudioFormatFlagIsSignedInteger) != 0;
    if (isFloat && context->bitsPerChannel == 32) {
        DarwinEqualizerApplyFloat32Gain(bufferListInOut, linearGain);
    } else if (isSignedInteger && context->bitsPerChannel == 16) {
        DarwinEqualizerApplySInt16Gain(bufferListInOut, linearGain);
    }
}

@implementation DarwinEqualizer {
    DarwinEqualizerTapState *_state;
}

- (instancetype)init {
    self = [super init];
    NSAssert(self, @"super init cannot be nil");
    _state = calloc(1, sizeof(DarwinEqualizerTapState));
    NSAssert(_state, @"equalizer state cannot be nil");
    atomic_init(&_state->enabled, false);
    for (int i = 0; i < DARWIN_EQUALIZER_BAND_COUNT; i++) {
        atomic_init(&_state->gainsCentibels[i], 0);
    }
    return self;
}

- (void)dealloc {
    if (_state) {
        free(_state);
        _state = NULL;
    }
}

- (DarwinEqualizerTapState *)tapState {
    return _state;
}

- (void)setEnabled:(BOOL)enabled {
    atomic_store_explicit(&_state->enabled, enabled, memory_order_relaxed);
}

- (NSDictionary<NSString *, NSObject *> *)parameters {
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *bands = [NSMutableArray arrayWithCapacity:DARWIN_EQUALIZER_BAND_COUNT];
    for (int i = 0; i < DARWIN_EQUALIZER_BAND_COUNT; i++) {
        int gainCentibels = atomic_load_explicit(&_state->gainsCentibels[i], memory_order_relaxed);
        [bands addObject:@{
            @"index": @(i),
            @"lowerFrequency": @(DarwinEqualizerLowerFrequencies[i]),
            @"upperFrequency": @(DarwinEqualizerUpperFrequencies[i]),
            @"centerFrequency": @(DarwinEqualizerCenterFrequencies[i]),
            @"gain": @((double)gainCentibels / DARWIN_EQUALIZER_GAIN_SCALE),
        }];
    }
    return @{
        @"minDecibels": @(DARWIN_EQUALIZER_MIN_DECIBELS),
        @"maxDecibels": @(DARWIN_EQUALIZER_MAX_DECIBELS),
        @"bands": bands,
    };
}

- (BOOL)setGain:(double)gain forBandIndex:(NSInteger)bandIndex {
    if (bandIndex < 0 || bandIndex >= DARWIN_EQUALIZER_BAND_COUNT) {
        return NO;
    }
    double clampedGain = DarwinEqualizerClampDouble(gain, DARWIN_EQUALIZER_MIN_DECIBELS, DARWIN_EQUALIZER_MAX_DECIBELS);
    int gainCentibels = (int)lrint(clampedGain * DARWIN_EQUALIZER_GAIN_SCALE);
    atomic_store_explicit(&_state->gainsCentibels[bandIndex], gainCentibels, memory_order_relaxed);
    return YES;
}

- (MTAudioProcessingTapRef)newTapProcessor {
    MTAudioProcessingTapCallbacks callbacks;
    callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
    callbacks.clientInfo = (__bridge void *)self;
    callbacks.init = DarwinEqualizerTapInit;
    callbacks.finalize = DarwinEqualizerTapFinalize;
    callbacks.prepare = DarwinEqualizerTapPrepare;
    callbacks.unprepare = DarwinEqualizerTapUnprepare;
    callbacks.process = DarwinEqualizerTapProcess;

    MTAudioProcessingTapRef tap = NULL;
    OSStatus status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap);
    if (status != noErr) {
        return NULL;
    }
    return tap;
}

@end
