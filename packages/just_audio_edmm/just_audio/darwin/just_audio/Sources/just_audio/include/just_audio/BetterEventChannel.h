#import <AVFoundation/AVFoundation.h>
#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif

@interface BetterEventChannel : NSObject<FlutterStreamHandler>

- (instancetype)initWithName:(NSString*)name messenger:(NSObject<FlutterBinaryMessenger> *)messenger;
- (instancetype)initWithName:(NSString*)name
                   messenger:(NSObject<FlutterBinaryMessenger> *)messenger
                    onListen:(void (^)(void))onListen
                    onCancel:(void (^)(void))onCancel;
- (void)sendEvent:(id)event;
- (void)dispose;

@end
