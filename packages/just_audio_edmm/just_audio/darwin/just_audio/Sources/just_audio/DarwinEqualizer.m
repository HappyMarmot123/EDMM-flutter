#import "./include/just_audio/DarwinEqualizer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <dispatch/dispatch.h>
#import <math.h>
#import <stdbool.h>
#import <stdint.h>
#import <stdatomic.h>
#import <stdlib.h>

#define DARWIN_EQUALIZER_BAND_COUNT 5
#define DARWIN_EQUALIZER_MIN_DECIBELS -12.0
#define DARWIN_EQUALIZER_MAX_DECIBELS 12.0
#define DARWIN_EQUALIZER_GAIN_SCALE 100.0
#define DARWIN_EQUALIZER_MIN_Q 0.25
#define DARWIN_EQUALIZER_MAX_Q 4.0
#define DARWIN_EQUALIZER_ENABLE_RAMP_SECONDS 0.005
#define DARWIN_EQUALIZER_TWO_PI 6.28318530717958647692
#define DARWIN_SPECTRUM_BIN_COUNT 24
#define DARWIN_SPECTRUM_FFT_SIZE 1024
#define DARWIN_SPECTRUM_MAILBOX_SLOT_COUNT 3
#define DARWIN_SPECTRUM_FRAME_INTERVAL_SECONDS 0.04
#define DARWIN_SPECTRUM_MIN_FREQUENCY 40.0
#define DARWIN_SPECTRUM_MAX_FREQUENCY 20000.0
#define DARWIN_SPECTRUM_MIN_DECIBELS -80.0

enum DarwinSpectrumMailboxStatus {
    DarwinSpectrumMailboxFree = 0,
    DarwinSpectrumMailboxWriting = 1,
    DarwinSpectrumMailboxReady = 2,
    DarwinSpectrumMailboxReading = 3,
};

enum DarwinSpectrumSupportStatus {
    DarwinSpectrumPending = 0,
    DarwinSpectrumSupported = 1,
    DarwinSpectrumUnavailable = 2,
};

enum DarwinSpectrumUnavailableReason {
    DarwinSpectrumNoUnavailableReason = 0,
    DarwinSpectrumTapUnavailable = 1,
    DarwinSpectrumUnsupportedPCM = 2,
};

static char DarwinSpectrumQueueKey;

typedef struct DarwinSpectrumMailboxSlot {
    atomic_int status;
    double sampleRate;
    Float32 samples[DARWIN_SPECTRUM_FFT_SIZE];
} DarwinSpectrumMailboxSlot;

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
    atomic_uint parameterGeneration;
    atomic_bool spectrumCaptureEnabled;
    atomic_uint spectrumCaptureGeneration;
    atomic_int spectrumSupportStatus;
    atomic_int spectrumUnavailableReason;
    DarwinSpectrumMailboxSlot spectrumMailbox[DARWIN_SPECTRUM_MAILBOX_SLOT_COUNT];
} DarwinEqualizerTapState;

typedef struct DarwinEqualizerBiquadCoefficients {
    double b0;
    double b1;
    double b2;
    double a1;
    double a2;
} DarwinEqualizerBiquadCoefficients;

typedef struct DarwinEqualizerBiquadState {
    double z1;
    double z2;
} DarwinEqualizerBiquadState;

typedef struct DarwinEqualizerTapContext {
    void *owner;
    DarwinEqualizerTapState *state;
    AudioFormatID formatID;
    AudioFormatFlags formatFlags;
    UInt32 bitsPerChannel;
    double sampleRate;
    UInt32 channelCount;
    DarwinEqualizerBiquadCoefficients coefficients[DARWIN_EQUALIZER_BAND_COUNT];
    DarwinEqualizerBiquadState *filterStates;
    unsigned int observedParameterGeneration;
    bool observedEnabled;
    double wetMix;
    double wetTarget;
    UInt32 wetRampFramesRemaining;
    Float32 spectrumAccumulator[DARWIN_SPECTRUM_FFT_SIZE];
    UInt32 spectrumAccumulatorCount;
} DarwinEqualizerTapContext;

@interface DarwinEqualizer ()
- (DarwinEqualizerTapState *)tapState;
- (void)performOnSpectrumQueueSynchronously:(dispatch_block_t)block;
- (void)emitSpectrumSupportIfNeeded:(unsigned int)captureGeneration;
- (void)dispatchSpectrumEvent:(NSDictionary<NSString *, NSObject *> *)event
            captureGeneration:(unsigned int)captureGeneration;
- (void)emitSpectrumFrame;
@end

static void DarwinEqualizerSetSpectrumSupport(
    DarwinEqualizerTapState *state,
    int supportStatus,
    int unavailableReason) {
    atomic_store_explicit(
        &state->spectrumUnavailableReason,
        unavailableReason,
        memory_order_relaxed);
    atomic_store_explicit(
        &state->spectrumSupportStatus,
        supportStatus,
        memory_order_release);
}

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

static DarwinEqualizerBiquadCoefficients DarwinEqualizerIdentityCoefficients(void) {
    DarwinEqualizerBiquadCoefficients coefficients = {
        .b0 = 1.0,
        .b1 = 0.0,
        .b2 = 0.0,
        .a1 = 0.0,
        .a2 = 0.0,
    };
    return coefficients;
}

static double DarwinEqualizerBandQ(int bandIndex) {
    double bandwidth = DarwinEqualizerUpperFrequencies[bandIndex] - DarwinEqualizerLowerFrequencies[bandIndex];
    if (bandwidth <= 0.0) return 1.0;
    return DarwinEqualizerClampDouble(
        DarwinEqualizerCenterFrequencies[bandIndex] / bandwidth,
        DARWIN_EQUALIZER_MIN_Q,
        DARWIN_EQUALIZER_MAX_Q);
}

static DarwinEqualizerBiquadCoefficients DarwinEqualizerMakePeakingCoefficients(
    double sampleRate,
    double centerFrequency,
    double q,
    double gainDecibels) {
    if (!isfinite(sampleRate) || sampleRate <= 0.0 ||
            !isfinite(centerFrequency) || centerFrequency <= 0.0 ||
            centerFrequency >= sampleRate * 0.5 ||
            !isfinite(q) || q <= 0.0 ||
            fabs(gainDecibels) < 0.000001) {
        return DarwinEqualizerIdentityCoefficients();
    }

    double amplitude = pow(10.0, gainDecibels / 40.0);
    double omega = DARWIN_EQUALIZER_TWO_PI * centerFrequency / sampleRate;
    double alpha = sin(omega) / (2.0 * q);
    double cosine = cos(omega);
    double a0 = 1.0 + alpha / amplitude;
    DarwinEqualizerBiquadCoefficients coefficients = {
        .b0 = (1.0 + alpha * amplitude) / a0,
        .b1 = (-2.0 * cosine) / a0,
        .b2 = (1.0 - alpha * amplitude) / a0,
        .a1 = (-2.0 * cosine) / a0,
        .a2 = (1.0 - alpha / amplitude) / a0,
    };
    return coefficients;
}

static double DarwinEqualizerApplyBiquad(
    double input,
    const DarwinEqualizerBiquadCoefficients *coefficients,
    DarwinEqualizerBiquadState *state) {
    double output = coefficients->b0 * input + state->z1;
    state->z1 = coefficients->b1 * input - coefficients->a1 * output + state->z2;
    state->z2 = coefficients->b2 * input - coefficients->a2 * output;
    if (fabs(state->z1) < 1.0e-30) state->z1 = 0.0;
    if (fabs(state->z2) < 1.0e-30) state->z2 = 0.0;
    return output;
}

static void DarwinEqualizerReleaseFilterStates(DarwinEqualizerTapContext *context) {
    if (context->filterStates) {
        free(context->filterStates);
        context->filterStates = NULL;
    }
    context->channelCount = 0;
}

static void DarwinEqualizerResetFilterStates(DarwinEqualizerTapContext *context) {
    if (!context->filterStates) return;
    size_t stateCount = (size_t)context->channelCount * DARWIN_EQUALIZER_BAND_COUNT;
    for (size_t stateIndex = 0; stateIndex < stateCount; stateIndex++) {
        context->filterStates[stateIndex].z1 = 0.0;
        context->filterStates[stateIndex].z2 = 0.0;
    }
}

static void DarwinEqualizerRefreshCoefficients(DarwinEqualizerTapContext *context) {
    unsigned int generation = atomic_load_explicit(
        &context->state->parameterGeneration,
        memory_order_acquire);
    if (generation == context->observedParameterGeneration) return;

    for (int bandIndex = 0; bandIndex < DARWIN_EQUALIZER_BAND_COUNT; bandIndex++) {
        int gainCentibels = atomic_load_explicit(
            &context->state->gainsCentibels[bandIndex],
            memory_order_acquire);
        double gainDecibels = DarwinEqualizerClampDouble(
            (double)gainCentibels / DARWIN_EQUALIZER_GAIN_SCALE,
            DARWIN_EQUALIZER_MIN_DECIBELS,
            DARWIN_EQUALIZER_MAX_DECIBELS);
        context->coefficients[bandIndex] = DarwinEqualizerMakePeakingCoefficients(
            context->sampleRate,
            DarwinEqualizerCenterFrequencies[bandIndex],
            DarwinEqualizerBandQ(bandIndex),
            gainDecibels);
    }
    context->observedParameterGeneration = generation;
}

static UInt32 DarwinEqualizerRampFrameCount(const DarwinEqualizerTapContext *context) {
    double frames = context->sampleRate * DARWIN_EQUALIZER_ENABLE_RAMP_SECONDS;
    if (!isfinite(frames) || frames < 1.0) return 1;
    if (frames > UINT32_MAX) return UINT32_MAX;
    return (UInt32)lrint(frames);
}

static void DarwinEqualizerRefreshEnabled(DarwinEqualizerTapContext *context) {
    bool enabled = atomic_load_explicit(&context->state->enabled, memory_order_acquire);
    if (enabled == context->observedEnabled) return;
    if (enabled && context->wetMix <= 0.000001) {
        DarwinEqualizerResetFilterStates(context);
    }
    context->observedEnabled = enabled;
    context->wetTarget = enabled ? 1.0 : 0.0;
    context->wetRampFramesRemaining = DarwinEqualizerRampFrameCount(context);
}

static double DarwinEqualizerProcessChannelSample(
    DarwinEqualizerTapContext *context,
    UInt32 channelIndex,
    double input) {
    double output = input;
    DarwinEqualizerBiquadState *channelStates =
        context->filterStates + ((size_t)channelIndex * DARWIN_EQUALIZER_BAND_COUNT);
    for (int bandIndex = 0; bandIndex < DARWIN_EQUALIZER_BAND_COUNT; bandIndex++) {
        output = DarwinEqualizerApplyBiquad(
            output,
            &context->coefficients[bandIndex],
            &channelStates[bandIndex]);
    }
    return output;
}

static double DarwinEqualizerWetMixForFrame(
    const DarwinEqualizerTapContext *context,
    double wetStep,
    CMItemCount frameIndex) {
    if ((uint64_t)frameIndex >= context->wetRampFramesRemaining) {
        return context->wetTarget;
    }
    return context->wetMix + wetStep * (double)(frameIndex + 1);
}

static void DarwinEqualizerProcessFloat32(
    DarwinEqualizerTapContext *context,
    AudioBufferList *bufferList,
    CMItemCount frameCount,
    bool nonInterleaved,
    double wetStep) {
    UInt32 firstChannelInBuffer = 0;
    for (UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; bufferIndex++) {
        AudioBuffer *buffer = &bufferList->mBuffers[bufferIndex];
        Float32 *samples = (Float32 *)buffer->mData;
        UInt32 channelsInBuffer = nonInterleaved ? 1 : buffer->mNumberChannels;
        if (!samples || channelsInBuffer == 0) {
            firstChannelInBuffer += channelsInBuffer;
            continue;
        }

        UInt32 availableSamples = buffer->mDataByteSize / sizeof(Float32);
        CMItemCount availableFrames = (CMItemCount)(availableSamples / channelsInBuffer);
        CMItemCount framesToProcess = frameCount < availableFrames ? frameCount : availableFrames;
        UInt32 processableChannels = channelsInBuffer;
        if (firstChannelInBuffer >= context->channelCount) {
            processableChannels = 0;
        } else if (firstChannelInBuffer + processableChannels > context->channelCount) {
            processableChannels = context->channelCount - firstChannelInBuffer;
        }

        for (CMItemCount frameIndex = 0; frameIndex < framesToProcess; frameIndex++) {
            double wetMix = DarwinEqualizerWetMixForFrame(context, wetStep, frameIndex);
            for (UInt32 channelOffset = 0; channelOffset < processableChannels; channelOffset++) {
                size_t sampleIndex = (size_t)frameIndex * channelsInBuffer + channelOffset;
                double dry = samples[sampleIndex];
                double wet = DarwinEqualizerProcessChannelSample(
                    context,
                    firstChannelInBuffer + channelOffset,
                    dry);
                samples[sampleIndex] = DarwinEqualizerClampFloat32(
                    (Float32)(dry + wetMix * (wet - dry)),
                    -1.0f,
                    1.0f);
            }
        }
        firstChannelInBuffer += channelsInBuffer;
    }
}

static void DarwinEqualizerProcessSInt16(
    DarwinEqualizerTapContext *context,
    AudioBufferList *bufferList,
    CMItemCount frameCount,
    bool nonInterleaved,
    double wetStep) {
    UInt32 firstChannelInBuffer = 0;
    for (UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; bufferIndex++) {
        AudioBuffer *buffer = &bufferList->mBuffers[bufferIndex];
        SInt16 *samples = (SInt16 *)buffer->mData;
        UInt32 channelsInBuffer = nonInterleaved ? 1 : buffer->mNumberChannels;
        if (!samples || channelsInBuffer == 0) {
            firstChannelInBuffer += channelsInBuffer;
            continue;
        }

        UInt32 availableSamples = buffer->mDataByteSize / sizeof(SInt16);
        CMItemCount availableFrames = (CMItemCount)(availableSamples / channelsInBuffer);
        CMItemCount framesToProcess = frameCount < availableFrames ? frameCount : availableFrames;
        UInt32 processableChannels = channelsInBuffer;
        if (firstChannelInBuffer >= context->channelCount) {
            processableChannels = 0;
        } else if (firstChannelInBuffer + processableChannels > context->channelCount) {
            processableChannels = context->channelCount - firstChannelInBuffer;
        }

        for (CMItemCount frameIndex = 0; frameIndex < framesToProcess; frameIndex++) {
            double wetMix = DarwinEqualizerWetMixForFrame(context, wetStep, frameIndex);
            for (UInt32 channelOffset = 0; channelOffset < processableChannels; channelOffset++) {
                size_t sampleIndex = (size_t)frameIndex * channelsInBuffer + channelOffset;
                double dry = (double)samples[sampleIndex] / 32768.0;
                double wet = DarwinEqualizerProcessChannelSample(
                    context,
                    firstChannelInBuffer + channelOffset,
                    dry);
                double output = dry + wetMix * (wet - dry);
                samples[sampleIndex] = DarwinEqualizerClampSInt16(output * 32768.0);
            }
        }
        firstChannelInBuffer += channelsInBuffer;
    }
}

static void DarwinEqualizerPublishSpectrumAccumulator(
    DarwinEqualizerTapContext *context) {
    DarwinSpectrumMailboxSlot *claimedSlot = NULL;
    for (int slotIndex = 0; slotIndex < DARWIN_SPECTRUM_MAILBOX_SLOT_COUNT; slotIndex++) {
        DarwinSpectrumMailboxSlot *slot = &context->state->spectrumMailbox[slotIndex];
        int expected = DarwinSpectrumMailboxFree;
        if (atomic_compare_exchange_strong_explicit(
                &slot->status,
                &expected,
                DarwinSpectrumMailboxWriting,
                memory_order_acq_rel,
                memory_order_relaxed)) {
            claimedSlot = slot;
            break;
        }
    }
    if (claimedSlot) {
        claimedSlot->sampleRate = context->sampleRate;
        for (int sampleIndex = 0; sampleIndex < DARWIN_SPECTRUM_FFT_SIZE; sampleIndex++) {
            claimedSlot->samples[sampleIndex] = context->spectrumAccumulator[sampleIndex];
        }
        atomic_store_explicit(
            &claimedSlot->status,
            DarwinSpectrumMailboxReady,
            memory_order_release);
    }
    context->spectrumAccumulatorCount = 0;
}

static void DarwinEqualizerAppendSpectrumSample(
    DarwinEqualizerTapContext *context,
    double sample) {
    context->spectrumAccumulator[context->spectrumAccumulatorCount++] =
        DarwinEqualizerClampFloat32((Float32)sample, -1.0f, 1.0f);
    if (context->spectrumAccumulatorCount == DARWIN_SPECTRUM_FFT_SIZE) {
        DarwinEqualizerPublishSpectrumAccumulator(context);
    }
}

static void DarwinEqualizerCaptureSpectrum(
    DarwinEqualizerTapContext *context,
    AudioBufferList *bufferList,
    CMItemCount frameCount,
    bool isFloat,
    bool isSignedInteger,
    bool nonInterleaved) {
    if (!atomic_load_explicit(
            &context->state->spectrumCaptureEnabled,
            memory_order_acquire)) {
        context->spectrumAccumulatorCount = 0;
        return;
    }
    if ((!isFloat || context->bitsPerChannel != 32) &&
            (!isSignedInteger || context->bitsPerChannel != 16)) {
        return;
    }

    for (CMItemCount frameIndex = 0; frameIndex < frameCount; frameIndex++) {
        double mixedSample = 0.0;
        UInt32 mixedChannelCount = 0;
        for (UInt32 bufferIndex = 0; bufferIndex < bufferList->mNumberBuffers; bufferIndex++) {
            AudioBuffer *buffer = &bufferList->mBuffers[bufferIndex];
            UInt32 channelsInBuffer = nonInterleaved ? 1 : buffer->mNumberChannels;
            if (!buffer->mData || channelsInBuffer == 0) continue;
            UInt32 bytesPerSample = isFloat ? sizeof(Float32) : sizeof(SInt16);
            UInt32 availableSamples = buffer->mDataByteSize / bytesPerSample;
            CMItemCount availableFrames = (CMItemCount)(availableSamples / channelsInBuffer);
            if (frameIndex >= availableFrames) continue;

            for (UInt32 channelOffset = 0; channelOffset < channelsInBuffer; channelOffset++) {
                size_t sampleIndex = (size_t)frameIndex * channelsInBuffer + channelOffset;
                if (isFloat) {
                    Float32 *samples = (Float32 *)buffer->mData;
                    Float32 sample = samples[sampleIndex];
                    mixedSample += isfinite(sample) ? sample : 0.0;
                } else {
                    SInt16 *samples = (SInt16 *)buffer->mData;
                    mixedSample += (double)samples[sampleIndex] / 32768.0;
                }
                mixedChannelCount++;
            }
        }
        if (mixedChannelCount > 0) {
            DarwinEqualizerAppendSpectrumSample(
                context,
                mixedSample / mixedChannelCount);
        }
    }
}

static DarwinSpectrumMailboxSlot *DarwinEqualizerClaimReadySpectrumSlot(
    DarwinEqualizerTapState *state) {
    for (int slotIndex = 0; slotIndex < DARWIN_SPECTRUM_MAILBOX_SLOT_COUNT; slotIndex++) {
        DarwinSpectrumMailboxSlot *slot = &state->spectrumMailbox[slotIndex];
        int expected = DarwinSpectrumMailboxReady;
        if (atomic_compare_exchange_strong_explicit(
                &slot->status,
                &expected,
                DarwinSpectrumMailboxReading,
                memory_order_acq_rel,
                memory_order_relaxed)) {
            return slot;
        }
    }
    return NULL;
}

static void DarwinSpectrumFFT(double *real, double *imaginary) {
    for (int index = 1, reversed = 0; index < DARWIN_SPECTRUM_FFT_SIZE; index++) {
        int bit = DARWIN_SPECTRUM_FFT_SIZE >> 1;
        for (; (reversed & bit) != 0; bit >>= 1) reversed ^= bit;
        reversed ^= bit;
        if (index < reversed) {
            double realValue = real[index];
            real[index] = real[reversed];
            real[reversed] = realValue;
            double imaginaryValue = imaginary[index];
            imaginary[index] = imaginary[reversed];
            imaginary[reversed] = imaginaryValue;
        }
    }
    for (int length = 2; length <= DARWIN_SPECTRUM_FFT_SIZE; length <<= 1) {
        double angle = -DARWIN_EQUALIZER_TWO_PI / length;
        double stepReal = cos(angle);
        double stepImaginary = sin(angle);
        for (int offset = 0; offset < DARWIN_SPECTRUM_FFT_SIZE; offset += length) {
            double weightReal = 1.0;
            double weightImaginary = 0.0;
            for (int index = 0; index < length / 2; index++) {
                int even = offset + index;
                int odd = even + length / 2;
                double oddReal =
                    real[odd] * weightReal - imaginary[odd] * weightImaginary;
                double oddImaginary =
                    real[odd] * weightImaginary + imaginary[odd] * weightReal;
                real[odd] = real[even] - oddReal;
                imaginary[odd] = imaginary[even] - oddImaginary;
                real[even] += oddReal;
                imaginary[even] += oddImaginary;
                double nextWeightReal =
                    weightReal * stepReal - weightImaginary * stepImaginary;
                weightImaginary =
                    weightReal * stepImaginary + weightImaginary * stepReal;
                weightReal = nextWeightReal;
            }
        }
    }
}

static void DarwinEqualizerAdvanceWetRamp(
    DarwinEqualizerTapContext *context,
    CMItemCount frameCount,
    double wetStep) {
    if (context->wetRampFramesRemaining == 0) return;
    UInt32 framesAdvanced = frameCount < (CMItemCount)context->wetRampFramesRemaining
        ? (UInt32)frameCount
        : context->wetRampFramesRemaining;
    context->wetMix += wetStep * framesAdvanced;
    context->wetRampFramesRemaining -= framesAdvanced;
    if (context->wetRampFramesRemaining == 0) {
        context->wetMix = context->wetTarget;
        if (context->wetTarget == 0.0) {
            DarwinEqualizerResetFilterStates(context);
        }
    }
}

static void DarwinEqualizerTapInit(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    DarwinEqualizer *equalizer = (__bridge DarwinEqualizer *)clientInfo;
    DarwinEqualizerTapContext *context = calloc(1, sizeof(DarwinEqualizerTapContext));
    if (!context) {
        [equalizer markSpectrumTapUnavailable];
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
    DarwinEqualizerReleaseFilterStates(context);
    if (context->owner) {
        (void)CFBridgingRelease(context->owner);
        context->owner = NULL;
    }
    free(context);
}

static void DarwinEqualizerTapPrepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat) {
    DarwinEqualizerTapContext *context = (DarwinEqualizerTapContext *)MTAudioProcessingTapGetStorage(tap);
    if (!context) return;
    if (!processingFormat) {
        DarwinEqualizerSetSpectrumSupport(
            context->state,
            DarwinSpectrumUnavailable,
            DarwinSpectrumUnsupportedPCM);
        return;
    }
    (void)maxFrames;
    DarwinEqualizerReleaseFilterStates(context);
    context->formatID = processingFormat->mFormatID;
    context->formatFlags = processingFormat->mFormatFlags;
    context->bitsPerChannel = processingFormat->mBitsPerChannel;
    context->sampleRate = processingFormat->mSampleRate;
    context->channelCount = processingFormat->mChannelsPerFrame;
    bool isLinearPCM = context->formatID == kAudioFormatLinearPCM;
    bool isFloat32 =
        (context->formatFlags & kAudioFormatFlagIsFloat) != 0 &&
        context->bitsPerChannel == 32;
    bool isSignedInteger16 =
        (context->formatFlags & kAudioFormatFlagIsSignedInteger) != 0 &&
        context->bitsPerChannel == 16;
    bool spectrumSupported =
        isLinearPCM &&
        context->channelCount > 0 &&
        isfinite(context->sampleRate) &&
        context->sampleRate > DARWIN_SPECTRUM_MIN_FREQUENCY * 2.0 &&
        (isFloat32 || isSignedInteger16);
    DarwinEqualizerSetSpectrumSupport(
        context->state,
        spectrumSupported ? DarwinSpectrumSupported : DarwinSpectrumUnavailable,
        spectrumSupported
            ? DarwinSpectrumNoUnavailableReason
            : DarwinSpectrumUnsupportedPCM);
    if (context->channelCount == 0) return;

    size_t stateCount = (size_t)context->channelCount * DARWIN_EQUALIZER_BAND_COUNT;
    context->filterStates = calloc(stateCount, sizeof(DarwinEqualizerBiquadState));
    if (!context->filterStates) {
        context->channelCount = 0;
        return;
    }
    context->observedParameterGeneration = ~0u;
    DarwinEqualizerRefreshCoefficients(context);
    context->observedEnabled = atomic_load_explicit(&context->state->enabled, memory_order_acquire);
    context->wetMix = 0.0;
    context->wetTarget = context->observedEnabled ? 1.0 : 0.0;
    context->wetRampFramesRemaining = context->observedEnabled
        ? DarwinEqualizerRampFrameCount(context)
        : 0;
}

static void DarwinEqualizerTapUnprepare(MTAudioProcessingTapRef tap) {
    DarwinEqualizerTapContext *context = (DarwinEqualizerTapContext *)MTAudioProcessingTapGetStorage(tap);
    if (!context) return;
    DarwinEqualizerReleaseFilterStates(context);
}

static void DarwinEqualizerTapProcess(
    MTAudioProcessingTapRef tap,
    CMItemCount numberFrames,
    MTAudioProcessingTapFlags flags,
    AudioBufferList *bufferListInOut,
    CMItemCount *numberFramesOut,
    MTAudioProcessingTapFlags *flagsOut) {
    (void)flags;
    OSStatus status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, NULL, numberFramesOut);
    if (status != noErr) {
        if (numberFramesOut) {
            *numberFramesOut = 0;
        }
        return;
    }

    DarwinEqualizerTapContext *context = (DarwinEqualizerTapContext *)MTAudioProcessingTapGetStorage(tap);
    if (!context || !context->state || context->formatID != kAudioFormatLinearPCM) return;
    CMItemCount outputFrameCount = numberFramesOut ? *numberFramesOut : numberFrames;
    if (outputFrameCount <= 0) return;
    bool isFloat = (context->formatFlags & kAudioFormatFlagIsFloat) != 0;
    bool isSignedInteger = (context->formatFlags & kAudioFormatFlagIsSignedInteger) != 0;
    bool isNonInterleaved = (context->formatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    DarwinEqualizerCaptureSpectrum(
        context,
        bufferListInOut,
        outputFrameCount,
        isFloat,
        isSignedInteger,
        isNonInterleaved);

    if (!context->filterStates) return;
    DarwinEqualizerRefreshCoefficients(context);
    DarwinEqualizerRefreshEnabled(context);
    if (context->wetMix == 0.0 && context->wetTarget == 0.0) return;
    double wetStep = context->wetRampFramesRemaining > 0
        ? (context->wetTarget - context->wetMix) / context->wetRampFramesRemaining
        : 0.0;
    if (isFloat && context->bitsPerChannel == 32) {
        DarwinEqualizerProcessFloat32(
            context,
            bufferListInOut,
            outputFrameCount,
            isNonInterleaved,
            wetStep);
    } else if (isSignedInteger && context->bitsPerChannel == 16) {
        DarwinEqualizerProcessSInt16(
            context,
            bufferListInOut,
            outputFrameCount,
            isNonInterleaved,
            wetStep);
    }
    DarwinEqualizerAdvanceWetRamp(context, outputFrameCount, wetStep);
}

@implementation DarwinEqualizer {
    DarwinEqualizerTapState *_state;
    dispatch_queue_t _spectrumQueue;
    dispatch_source_t _spectrumTimer;
    void (^_spectrumEventHandler)(NSDictionary<NSString *, NSObject *> *event);
    double _spectrumWindow[DARWIN_SPECTRUM_FFT_SIZE];
    double _spectrumReal[DARWIN_SPECTRUM_FFT_SIZE];
    double _spectrumImaginary[DARWIN_SPECTRUM_FFT_SIZE];
    double _smoothedSpectrumBins[DARWIN_SPECTRUM_BIN_COUNT];
    int _emittedSpectrumSupportStatus;
    int _emittedSpectrumUnavailableReason;
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
    atomic_init(&_state->parameterGeneration, 0);
    atomic_init(&_state->spectrumCaptureEnabled, false);
    atomic_init(&_state->spectrumCaptureGeneration, 0);
    atomic_init(&_state->spectrumSupportStatus, DarwinSpectrumPending);
    atomic_init(
        &_state->spectrumUnavailableReason,
        DarwinSpectrumNoUnavailableReason);
    for (int slotIndex = 0; slotIndex < DARWIN_SPECTRUM_MAILBOX_SLOT_COUNT; slotIndex++) {
        atomic_init(
            &_state->spectrumMailbox[slotIndex].status,
            DarwinSpectrumMailboxFree);
    }
    for (int sampleIndex = 0; sampleIndex < DARWIN_SPECTRUM_FFT_SIZE; sampleIndex++) {
        _spectrumWindow[sampleIndex] = 0.5 - 0.5 * cos(
            DARWIN_EQUALIZER_TWO_PI * sampleIndex /
            (DARWIN_SPECTRUM_FFT_SIZE - 1));
    }
    _spectrumQueue = dispatch_queue_create(
        "com.ryanheise.just_audio.spectrum.analysis",
        DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(
        _spectrumQueue,
        &DarwinSpectrumQueueKey,
        &DarwinSpectrumQueueKey,
        NULL);
    _emittedSpectrumSupportStatus = -1;
    _emittedSpectrumUnavailableReason = -1;
    return self;
}

- (void)dealloc {
    [self stopSpectrumCapture];
    if (_state) {
        free(_state);
        _state = NULL;
    }
}

- (DarwinEqualizerTapState *)tapState {
    return _state;
}

- (void)setEnabled:(BOOL)enabled {
    atomic_store_explicit(&_state->enabled, enabled, memory_order_release);
}

- (void)markSpectrumTapPending {
    DarwinEqualizerSetSpectrumSupport(
        _state,
        DarwinSpectrumPending,
        DarwinSpectrumNoUnavailableReason);
}

- (void)markSpectrumTapUnavailable {
    DarwinEqualizerSetSpectrumSupport(
        _state,
        DarwinSpectrumUnavailable,
        DarwinSpectrumTapUnavailable);
}

- (void)performOnSpectrumQueueSynchronously:(dispatch_block_t)block {
    if (!block) return;
    if (dispatch_get_specific(&DarwinSpectrumQueueKey)) {
        block();
        return;
    }
    dispatch_sync(_spectrumQueue, block);
}

- (void)startSpectrumCaptureWithHandler:(void (^)(NSDictionary<NSString *, NSObject *> *event))handler {
    [self performOnSpectrumQueueSynchronously:^{
        atomic_fetch_add_explicit(
            &self->_state->spectrumCaptureGeneration,
            1,
            memory_order_acq_rel);
        atomic_store_explicit(
            &self->_state->spectrumCaptureEnabled,
            false,
            memory_order_release);
        if (self->_spectrumTimer) {
            dispatch_source_cancel(self->_spectrumTimer);
            self->_spectrumTimer = nil;
        }
        self->_spectrumEventHandler = nil;
        if (!handler) return;

        self->_spectrumEventHandler = [handler copy];
        self->_emittedSpectrumSupportStatus = -1;
        self->_emittedSpectrumUnavailableReason = -1;
        for (int slotIndex = 0;
                slotIndex < DARWIN_SPECTRUM_MAILBOX_SLOT_COUNT;
                slotIndex++) {
            DarwinSpectrumMailboxSlot *slot =
                &self->_state->spectrumMailbox[slotIndex];
            int expected = DarwinSpectrumMailboxReady;
            atomic_compare_exchange_strong_explicit(
                &slot->status,
                &expected,
                DarwinSpectrumMailboxFree,
                memory_order_acq_rel,
                memory_order_relaxed);
        }
        atomic_store_explicit(
            &self->_state->spectrumCaptureEnabled,
            true,
            memory_order_release);
        self->_spectrumTimer = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER,
            0,
            0,
            self->_spectrumQueue);
        if (!self->_spectrumTimer) {
            atomic_store_explicit(
                &self->_state->spectrumCaptureEnabled,
                false,
                memory_order_release);
            self->_spectrumEventHandler = nil;
            return;
        }
        uint64_t interval = (uint64_t)(
            DARWIN_SPECTRUM_FRAME_INTERVAL_SECONDS * NSEC_PER_SEC);
        dispatch_source_set_timer(
            self->_spectrumTimer,
            dispatch_time(DISPATCH_TIME_NOW, 0),
            interval,
            interval / 5);
        __weak DarwinEqualizer *weakSelf = self;
        dispatch_source_set_event_handler(self->_spectrumTimer, ^{
            [weakSelf emitSpectrumFrame];
        });
        dispatch_resume(self->_spectrumTimer);
    }];
}

- (void)stopSpectrumCapture {
    if (!_state || !_spectrumQueue) return;
    // dealloc also calls this method, so the synchronous teardown block must
    // not retain a receiver that has already begun deallocation.
    __unsafe_unretained DarwinEqualizer *unsafeSelf = self;
    [self performOnSpectrumQueueSynchronously:^{
        atomic_fetch_add_explicit(
            &unsafeSelf->_state->spectrumCaptureGeneration,
            1,
            memory_order_acq_rel);
        atomic_store_explicit(
            &unsafeSelf->_state->spectrumCaptureEnabled,
            false,
            memory_order_release);
        if (unsafeSelf->_spectrumTimer) {
            dispatch_source_cancel(unsafeSelf->_spectrumTimer);
            unsafeSelf->_spectrumTimer = nil;
        }
        unsafeSelf->_spectrumEventHandler = nil;
    }];
}

- (void)dispatchSpectrumEvent:(NSDictionary<NSString *, NSObject *> *)event
            captureGeneration:(unsigned int)captureGeneration {
    void (^handler)(NSDictionary<NSString *, NSObject *> *) =
        _spectrumEventHandler;
    if (!handler) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (atomic_load_explicit(
                &self->_state->spectrumCaptureEnabled,
                memory_order_acquire) &&
                atomic_load_explicit(
                    &self->_state->spectrumCaptureGeneration,
                    memory_order_acquire) == captureGeneration) {
            handler(event);
        }
    });
}

- (void)emitSpectrumSupportIfNeeded:(unsigned int)captureGeneration {
    int supportStatus = atomic_load_explicit(
        &_state->spectrumSupportStatus,
        memory_order_acquire);
    int unavailableReason = atomic_load_explicit(
        &_state->spectrumUnavailableReason,
        memory_order_relaxed);
    if (supportStatus == DarwinSpectrumPending) {
        _emittedSpectrumSupportStatus = DarwinSpectrumPending;
        _emittedSpectrumUnavailableReason = DarwinSpectrumNoUnavailableReason;
        return;
    }
    if (supportStatus == _emittedSpectrumSupportStatus &&
            unavailableReason == _emittedSpectrumUnavailableReason) {
        return;
    }
    _emittedSpectrumSupportStatus = supportStatus;
    _emittedSpectrumUnavailableReason = unavailableReason;
    if (supportStatus == DarwinSpectrumSupported) {
        [self dispatchSpectrumEvent:@{@"available": @YES}
                  captureGeneration:captureGeneration];
        return;
    }
    NSString *reason = unavailableReason == DarwinSpectrumUnsupportedPCM
        ? @"unsupportedPcmEncoding"
        : @"tapUnavailable";
    [self dispatchSpectrumEvent:@{
        @"available": @NO,
        @"reason": reason,
    } captureGeneration:captureGeneration];
}

- (void)emitSpectrumFrame {
    if (!_state || !atomic_load_explicit(
            &_state->spectrumCaptureEnabled,
            memory_order_acquire)) {
        return;
    }
    unsigned int captureGeneration = atomic_load_explicit(
        &_state->spectrumCaptureGeneration,
        memory_order_acquire);
    [self emitSpectrumSupportIfNeeded:captureGeneration];
    if (atomic_load_explicit(
            &_state->spectrumSupportStatus,
            memory_order_acquire) != DarwinSpectrumSupported) {
        return;
    }
    DarwinSpectrumMailboxSlot *slot =
        DarwinEqualizerClaimReadySpectrumSlot(_state);
    if (!slot) return;
    double sampleRate = slot->sampleRate;
    for (int sampleIndex = 0; sampleIndex < DARWIN_SPECTRUM_FFT_SIZE; sampleIndex++) {
        _spectrumReal[sampleIndex] =
            slot->samples[sampleIndex] * _spectrumWindow[sampleIndex];
        _spectrumImaginary[sampleIndex] = 0.0;
    }
    atomic_store_explicit(
        &slot->status,
        DarwinSpectrumMailboxFree,
        memory_order_release);
    if (!isfinite(sampleRate) || sampleRate <= DARWIN_SPECTRUM_MIN_FREQUENCY * 2.0) {
        return;
    }

    DarwinSpectrumFFT(_spectrumReal, _spectrumImaginary);
    double maximumFrequency = fmin(
        DARWIN_SPECTRUM_MAX_FREQUENCY,
        sampleRate / 2.0);
    double ratio = pow(
        maximumFrequency / DARWIN_SPECTRUM_MIN_FREQUENCY,
        1.0 / DARWIN_SPECTRUM_BIN_COUNT);
    NSMutableArray<NSNumber *> *magnitudes =
        [NSMutableArray arrayWithCapacity:DARWIN_SPECTRUM_BIN_COUNT];
    for (int binIndex = 0; binIndex < DARWIN_SPECTRUM_BIN_COUNT; binIndex++) {
        double lowerFrequency =
            DARWIN_SPECTRUM_MIN_FREQUENCY * pow(ratio, binIndex);
        double upperFrequency =
            DARWIN_SPECTRUM_MIN_FREQUENCY * pow(ratio, binIndex + 1);
        int lowerIndex = (int)floor(
            lowerFrequency * DARWIN_SPECTRUM_FFT_SIZE / sampleRate);
        int upperIndex = (int)ceil(
            upperFrequency * DARWIN_SPECTRUM_FFT_SIZE / sampleRate);
        lowerIndex = lowerIndex < 1 ? 1 : lowerIndex;
        upperIndex = upperIndex > DARWIN_SPECTRUM_FFT_SIZE / 2
            ? DARWIN_SPECTRUM_FFT_SIZE / 2
            : upperIndex;
        double peak = 0.0;
        for (int frequencyIndex = lowerIndex;
                frequencyIndex <= upperIndex;
                frequencyIndex++) {
            peak = fmax(
                peak,
                hypot(
                    _spectrumReal[frequencyIndex],
                    _spectrumImaginary[frequencyIndex]));
        }
        double linearMagnitude = fmax(
            1.0e-5,
            peak * 2.0 / DARWIN_SPECTRUM_FFT_SIZE);
        double decibels = 20.0 * log10(linearMagnitude);
        double normalized = DarwinEqualizerClampDouble(
            (decibels - DARWIN_SPECTRUM_MIN_DECIBELS) /
                -DARWIN_SPECTRUM_MIN_DECIBELS,
            0.0,
            1.0);
        _smoothedSpectrumBins[binIndex] = fmax(
            normalized,
            _smoothedSpectrumBins[binIndex] * 0.82);
        [magnitudes addObject:@(_smoothedSpectrumBins[binIndex])];
    }

    NSDictionary<NSString *, NSObject *> *event = @{
        @"available": @YES,
        @"sampleRate": @((NSInteger)lrint(sampleRate)),
        @"timestamp": @((int64_t)llrint(
            [[NSDate date] timeIntervalSince1970] * 1000000.0)),
        @"magnitudes": magnitudes,
    };
    [self dispatchSpectrumEvent:event captureGeneration:captureGeneration];
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
    int previousGain = atomic_exchange_explicit(
        &_state->gainsCentibels[bandIndex],
        gainCentibels,
        memory_order_acq_rel);
    if (previousGain != gainCentibels) {
        atomic_fetch_add_explicit(
            &_state->parameterGeneration,
            1,
            memory_order_release);
    }
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
        [self markSpectrumTapUnavailable];
        return NULL;
    }
    return tap;
}

@end
