import '../playback/playback_snapshot.dart';
import '../result.dart';

class PlaybackTelemetrySink {
  const PlaybackTelemetrySink();

  void emit(PlaybackTelemetryEvent event) {}
}

class NoopPlaybackTelemetrySink extends PlaybackTelemetrySink {
  const NoopPlaybackTelemetrySink();
}

class PlaybackTelemetryEvent {
  const PlaybackTelemetryEvent({required this.name, required this.payload});

  factory PlaybackTelemetryEvent.errorReported(PlaybackSnapshot snapshot) {
    final failure = snapshot.error;
    return PlaybackTelemetryEvent(
      name: PlaybackTelemetryEventNames.errorReported,
      payload: {
        PlaybackTelemetryPayload.status: snapshot.status.name,
        PlaybackTelemetryPayload.hasCurrentTrack: snapshot.currentTrack != null,
        if (snapshot.queueIndex != null)
          PlaybackTelemetryPayload.queueIndex: snapshot.queueIndex,
        if (failure != null) ...{
          PlaybackTelemetryPayload.failureCategory: failure.category.name,
          PlaybackTelemetryPayload.failureRetryable: failure.isRetryable,
          if (failure case ServerFailure(:final statusCode))
            PlaybackTelemetryPayload.failureStatusCode: statusCode,
        },
      },
    );
  }

  final String name;
  final Map<String, Object?> payload;
}

class PlaybackTelemetryEventNames {
  const PlaybackTelemetryEventNames._();

  static const String errorReported = 'playback_error_reported';
}

class PlaybackTelemetryPayload {
  const PlaybackTelemetryPayload._();

  static const String status = 'playback_status';
  static const String hasCurrentTrack = 'has_current_track';
  static const String queueIndex = 'queue_index';
  static const String failureCategory = 'failure_category';
  static const String failureRetryable = 'failure_retryable';
  static const String failureStatusCode = 'failure_status_code';
}
