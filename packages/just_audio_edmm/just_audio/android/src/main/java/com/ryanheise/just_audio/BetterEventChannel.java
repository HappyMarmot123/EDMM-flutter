package com.ryanheise.just_audio;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;

public class BetterEventChannel implements EventSink {
    private EventSink eventSink;
    private final Runnable onListen;
    private final Runnable onCancel;

	public BetterEventChannel(final BinaryMessenger messenger, final String id) {
        this(messenger, id, null, null);
    }

	public BetterEventChannel(
            final BinaryMessenger messenger,
            final String id,
            final Runnable onListen,
            final Runnable onCancel) {
        this.onListen = onListen;
        this.onCancel = onCancel;
        EventChannel eventChannel = new EventChannel(messenger, id);
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(final Object arguments, final EventSink eventSink) {
                BetterEventChannel.this.eventSink = eventSink;
                if (BetterEventChannel.this.onListen != null) {
                    BetterEventChannel.this.onListen.run();
                }
            }

            @Override
            public void onCancel(final Object arguments) {
                if (BetterEventChannel.this.onCancel != null) {
                    BetterEventChannel.this.onCancel.run();
                }
                eventSink = null;
            }
        });
	}

    @Override
    public void success(Object event) {
        if (eventSink != null) eventSink.success(event);
    }

    @Override
    public void error(String errorCode, String errorMessage, Object errorDetails) {
        if (eventSink != null) eventSink.error(errorCode, errorMessage, errorDetails);
    }

    @Override
    public void endOfStream() {
        if (eventSink != null) eventSink.endOfStream();
    }
}
