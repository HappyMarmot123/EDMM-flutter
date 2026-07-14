import 'package:sentry_flutter/sentry_flutter.dart';

import '../../domain/telemetry/catalog_search_telemetry.dart';
import '../../domain/telemetry/local_library_telemetry.dart';
import '../../domain/telemetry/playback_telemetry.dart';

typedef SentryEventCapture = void Function(SentryEvent event);

class SentryTelemetryReporter {
  SentryTelemetryReporter({SentryEventCapture? capture})
    : _capture = capture ?? _captureWithSentry;

  final SentryEventCapture _capture;

  void captureTelemetryEvent(
    String name,
    Map<String, Object?> payload, {
    SentryLevel level = SentryLevel.info,
  }) {
    try {
      final contexts = Contexts();
      contexts['edmm_event'] = {'name': name, ..._sanitizePayload(payload)};
      _capture(
        SentryEvent(
          message: SentryMessage(name),
          level: level,
          logger: 'edmm.telemetry',
          tags: {'edmm_event': name},
          contexts: contexts,
        ),
      );
    } catch (_) {}
  }

  static void _captureWithSentry(SentryEvent event) {
    Sentry.captureEvent(event).ignore();
  }

  Map<String, Object?> _sanitizePayload(Map<String, Object?> payload) {
    return payload.map((key, value) => MapEntry(key, _sanitizeValue(value)));
  }

  Object? _sanitizeValue(Object? value) {
    return switch (value) {
      null => null,
      String() || num() || bool() => value,
      Iterable<Object?>() => value.map(_sanitizeValue).toList(growable: false),
      Map<Object?, Object?>() => value.map(
        (key, value) => MapEntry(key.toString(), _sanitizeValue(value)),
      ),
      _ => value.toString(),
    };
  }
}

class SentryCatalogSearchTelemetrySink extends CatalogSearchTelemetrySink {
  const SentryCatalogSearchTelemetrySink(this._reporter);

  final SentryTelemetryReporter _reporter;

  @override
  void emit(CatalogSearchTelemetryEvent event) {
    _reporter.captureTelemetryEvent(
      event.name,
      event.payload,
      level: _catalogLevel(event.name),
    );
  }

  SentryLevel _catalogLevel(String name) {
    return switch (name) {
      CatalogSearchTelemetryEventNames.failed => SentryLevel.warning,
      CatalogSearchTelemetryEventNames.staleFallbackUsed => SentryLevel.warning,
      CatalogSearchTelemetryEventNames.retryRequested => SentryLevel.info,
      _ => SentryLevel.info,
    };
  }
}

class SentryLocalLibraryTelemetrySink extends LocalLibraryTelemetrySink {
  const SentryLocalLibraryTelemetrySink(this._reporter);

  final SentryTelemetryReporter _reporter;

  @override
  void emit(LocalLibraryTelemetryEvent event) {
    _reporter.captureTelemetryEvent(
      event.name,
      event.payload,
      level: SentryLevel.warning,
    );
  }
}

class SentryPlaybackTelemetrySink extends PlaybackTelemetrySink {
  const SentryPlaybackTelemetrySink(this._reporter);

  final SentryTelemetryReporter _reporter;

  @override
  void emit(PlaybackTelemetryEvent event) {
    _reporter.captureTelemetryEvent(
      event.name,
      event.payload,
      level: SentryLevel.error,
    );
  }
}
