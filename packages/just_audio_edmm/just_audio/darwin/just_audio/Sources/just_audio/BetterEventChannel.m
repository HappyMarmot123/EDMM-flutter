#import "./include/just_audio/BetterEventChannel.h"

@implementation BetterEventChannel {
    FlutterEventChannel *_eventChannel;
    FlutterEventSink _eventSink;
    void (^_onListen)(void);
    void (^_onCancel)(void);
}

- (instancetype)initWithName:(NSString*)name messenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    return [self initWithName:name messenger:messenger onListen:nil onCancel:nil];
}

- (instancetype)initWithName:(NSString*)name
                   messenger:(NSObject<FlutterBinaryMessenger> *)messenger
                    onListen:(void (^)(void))onListen
                    onCancel:(void (^)(void))onCancel {
    self = [super init];
    NSAssert(self, @"super init cannot be nil");
    _eventChannel =
        [FlutterEventChannel eventChannelWithName:name binaryMessenger:messenger];
    [_eventChannel setStreamHandler:self];
    _eventSink = nil;
    _onListen = [onListen copy];
    _onCancel = [onCancel copy];
    return self;
}

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    _eventSink = eventSink;
    if (_onListen) _onListen();
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    if (_onCancel) _onCancel();
    _eventSink = nil;
    return nil;
}

- (void)sendEvent:(id)event {
    if (!_eventSink) return;
    _eventSink(event);
}

- (void)dispose {
    if (_eventSink) {
        @try {
            _eventSink(FlutterEndOfEventStream);
        } @catch (NSException *exception) {
            NSLog(@"Exception while ending event stream: %@", exception.reason);
        }
    }
    [_eventChannel setStreamHandler:nil];
}

@end
