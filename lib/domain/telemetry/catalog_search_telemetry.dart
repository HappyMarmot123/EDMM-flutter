import '../result.dart';

abstract class CatalogSearchTelemetrySink {
  const CatalogSearchTelemetrySink();
  void emit(CatalogSearchTelemetryEvent event);
}

class NoopCatalogSearchTelemetrySink extends CatalogSearchTelemetrySink {
  const NoopCatalogSearchTelemetrySink();

  @override
  void emit(CatalogSearchTelemetryEvent event) {}
}

class CatalogSearchTelemetryEvent {
  const CatalogSearchTelemetryEvent({
    required this.name,
    required this.payload,
  });

  final String name;
  final Map<String, Object?> payload;
}

class CatalogSearchTelemetryEventNames {
  const CatalogSearchTelemetryEventNames._();

  static const String requested = 'catalog_load_requested';
  static const String succeeded = 'catalog_load_succeeded';
  static const String failed = 'catalog_load_failed';
  static const String retryRequested = 'catalog_load_retry_requested';
  static const String staleFallbackUsed = 'catalog_load_stale_fallback_used';
}

class CatalogSearchTelemetryPayload {
  const CatalogSearchTelemetryPayload._();

  static const String view = 'view';
  static const String queryLength = 'query_length';
  static const String isRetry = 'is_retry';
  static const String forceRefresh = 'force_refresh';
  static const String resultCount = 'result_count';
  static const String hasResults = 'has_results';

  static const String failureCategory = 'failure_category';
  static const String failureRetryable = 'failure_retryable';
  static const String failureStatusCode = 'failure_status_code';
  static const String staleFallback = 'stale_fallback';
  static const String errorState = 'error_state';

  static Map<String, Object?> base({
    required String view,
    required String query,
    bool isRetry = false,
    bool forceRefresh = false,
  }) => {
    CatalogSearchTelemetryPayload.view: view,
    CatalogSearchTelemetryPayload.queryLength: query.length,
    CatalogSearchTelemetryPayload.isRetry: isRetry,
    CatalogSearchTelemetryPayload.forceRefresh: forceRefresh,
  };

  static Map<String, Object?> failurePayload({
    required String view,
    required String query,
    required Failure failure,
    required bool staleFallback,
  }) {
    return {
      ...base(view: view, query: query),
      CatalogSearchTelemetryPayload.failureCategory: failure.category.name,
      CatalogSearchTelemetryPayload.failureRetryable: failure.isRetryable,
      if (failure case ServerFailure(:final statusCode))
        CatalogSearchTelemetryPayload.failureStatusCode: statusCode,
      CatalogSearchTelemetryPayload.staleFallback: staleFallback,
    };
  }

  static Map<String, Object?> successPayload({
    required String view,
    required String query,
    required int resultCount,
  }) => {
    ...base(view: view, query: query),
    CatalogSearchTelemetryPayload.resultCount: resultCount,
    CatalogSearchTelemetryPayload.hasResults: resultCount > 0,
  };

  static Map<String, Object?> retryPayload({
    required String view,
    required String query,
    required bool forceRefresh,
  }) => {
    ...base(
      view: view,
      query: query,
      isRetry: true,
      forceRefresh: forceRefresh,
    ),
  };
}
