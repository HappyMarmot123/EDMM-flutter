import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/data/repositories/noop_local_library_repository.dart';
import 'package:edmm/domain/telemetry/local_library_telemetry.dart';
import 'package:edmm/main.dart';

class _LocalTelemetryRecorder extends LocalLibraryTelemetrySink {
  final events = <LocalLibraryTelemetryEvent>[];

  @override
  void emit(LocalLibraryTelemetryEvent event) => events.add(event);
}

void main() {
  test(
    'local repository emits telemetry when file setup falls back to memory',
    () async {
      final telemetry = _LocalTelemetryRecorder();

      final repo = await createLocalLibraryRepository(
        telemetry: telemetry,
        debugLogging: false,
        prefsFactory: () async => throw StateError('prefs failed'),
        inMemoryRepositoryFactory: InMemoryLocalLibraryRepository.new,
      );

      expect(repo, isA<InMemoryLocalLibraryRepository>());
      expect(telemetry.events, hasLength(1));
      expect(
        telemetry.events.single.name,
        LocalLibraryTelemetryEventNames.fallbackUsed,
      );
      expect(
        telemetry.events.single.payload[LocalLibraryTelemetryPayload
            .attemptedRepository],
        'file',
      );
      expect(
        telemetry.events.single.payload[LocalLibraryTelemetryPayload
            .fallbackRepository],
        'in_memory',
      );
      expect(
        telemetry.events.single.payload[LocalLibraryTelemetryPayload.errorType],
        'StateError',
      );
    },
  );

  test(
    'local repository emits telemetry when memory fallback uses noop',
    () async {
      final telemetry = _LocalTelemetryRecorder();

      final repo = await createLocalLibraryRepository(
        telemetry: telemetry,
        debugLogging: false,
        prefsFactory: () async => throw StateError('prefs failed'),
        inMemoryRepositoryFactory: () => throw StateError('memory failed'),
      );

      expect(repo, isA<NoopLocalLibraryRepository>());
      expect(telemetry.events, hasLength(2));
      expect(
        telemetry.events.last.payload[LocalLibraryTelemetryPayload
            .attemptedRepository],
        'in_memory',
      );
      expect(
        telemetry.events.last.payload[LocalLibraryTelemetryPayload
            .fallbackRepository],
        'noop',
      );
      expect(
        telemetry.events.last.payload[LocalLibraryTelemetryPayload.errorType],
        'StateError',
      );
    },
  );
}
