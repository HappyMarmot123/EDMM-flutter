class LocalLibraryTelemetrySink {
  const LocalLibraryTelemetrySink();

  void emit(LocalLibraryTelemetryEvent event) {}
}

class NoopLocalLibraryTelemetrySink extends LocalLibraryTelemetrySink {
  const NoopLocalLibraryTelemetrySink();
}

class LocalLibraryTelemetryEvent {
  const LocalLibraryTelemetryEvent({required this.name, required this.payload});

  factory LocalLibraryTelemetryEvent.fallbackUsed({
    required String attemptedRepository,
    required String fallbackRepository,
    required Object error,
  }) {
    return LocalLibraryTelemetryEvent(
      name: LocalLibraryTelemetryEventNames.fallbackUsed,
      payload: {
        LocalLibraryTelemetryPayload.attemptedRepository: attemptedRepository,
        LocalLibraryTelemetryPayload.fallbackRepository: fallbackRepository,
        LocalLibraryTelemetryPayload.errorType: error.runtimeType.toString(),
      },
    );
  }

  final String name;
  final Map<String, Object?> payload;
}

class LocalLibraryTelemetryEventNames {
  const LocalLibraryTelemetryEventNames._();

  static const String fallbackUsed = 'local_library_repository_fallback_used';
}

class LocalLibraryTelemetryPayload {
  const LocalLibraryTelemetryPayload._();

  static const String attemptedRepository = 'attempted_repository';
  static const String fallbackRepository = 'fallback_repository';
  static const String errorType = 'error_type';
}
