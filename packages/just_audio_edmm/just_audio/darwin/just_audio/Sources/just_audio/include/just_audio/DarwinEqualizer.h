#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <MediaToolbox/MediaToolbox.h>

@interface DarwinEqualizer : NSObject

- (void)setEnabled:(BOOL)enabled;
- (NSDictionary<NSString *, NSObject *> *)parameters;
- (BOOL)setGain:(double)gain forBandIndex:(NSInteger)bandIndex;
- (MTAudioProcessingTapRef)newTapProcessor CF_RETURNS_RETAINED;
- (void)markSpectrumTapPending;
- (void)markSpectrumTapUnavailable;
- (void)startSpectrumCaptureWithHandler:(void (^)(NSDictionary<NSString *, NSObject *> *event))handler;
- (void)stopSpectrumCapture;

@end
