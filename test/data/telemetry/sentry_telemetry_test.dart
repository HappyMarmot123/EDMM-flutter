import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:edmm/data/telemetry/sentry_telemetry.dart';
import 'package:edmm/domain/telemetry/catalog_search_telemetry.dart';
import 'package:edmm/domain/telemetry/local_library_telemetry.dart';
import 'package:edmm/domain/telemetry/playback_telemetry.dart';

void main() {
  test('catalog sink sends sanitized event payload to Sentry', () async {
    final captured = <SentryEvent>[];
    final reporter = SentryTelemetryReporter(capture: captured.add);
    final sink = SentryCatalogSearchTelemetrySink(reporter);

    sink.emit(
      const CatalogSearchTelemetryEvent(
        name: CatalogSearchTelemetryEventNames.failed,
        payload: {
          CatalogSearchTelemetryPayload.view: 'pop',
          CatalogSearchTelemetryPayload.queryLength: 5,
          CatalogSearchTelemetryPayload.failureCategory: 'network',
        },
      ),
    );

    expect(captured, hasLength(1));
    expect(
      captured.single.message?.formatted,
      CatalogSearchTelemetryEventNames.failed,
    );
    expect(captured.single.level, SentryLevel.warning);
    expect(captured.single.tags?['edmm_event'], 'catalog_load_failed');
    expect(captured.single.contexts['edmm_event']['view'], 'pop');
    expect(captured.single.contexts['edmm_event']['query_length'], 5);
    expect(
      captured.single.contexts['edmm_event'].containsKey('query'),
      isFalse,
    );
  });

  test('local and playback sinks share the same Sentry reporter', () async {
    final captured = <SentryEvent>[];
    final reporter = SentryTelemetryReporter(capture: captured.add);

    SentryLocalLibraryTelemetrySink(reporter).emit(
      LocalLibraryTelemetryEvent.fallbackUsed(
        attemptedRepository: 'file',
        fallbackRepository: 'in_memory',
        error: StateError('failed'),
      ),
    );
    SentryPlaybackTelemetrySink(reporter).emit(
      const PlaybackTelemetryEvent(
        name: PlaybackTelemetryEventNames.errorReported,
        payload: {
          PlaybackTelemetryPayload.status: 'error',
          PlaybackTelemetryPayload.failureCategory: 'parse',
        },
      ),
    );

    expect(captured, hasLength(2));
    expect(
      captured.first.message?.formatted,
      LocalLibraryTelemetryEventNames.fallbackUsed,
    );
    expect(
      captured.last.message?.formatted,
      PlaybackTelemetryEventNames.errorReported,
    );
    expect(captured.last.level, SentryLevel.error);
  });
}
