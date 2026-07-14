sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.error);
  final Failure error;
}

sealed class Failure {
  const Failure();
}

class NetworkFailure extends Failure {
  const NetworkFailure(this.cause);
  final Object cause;
}

class ServerFailure extends Failure {
  const ServerFailure(this.statusCode);
  final int statusCode;
}

class ParseFailure extends Failure {
  const ParseFailure(this.cause);
  final Object cause;
}

enum FailureCategory { network, server, parse, unknown }

extension FailureX on Failure {
  FailureCategory get category {
    return switch (this) {
      NetworkFailure() => FailureCategory.network,
      ServerFailure() => FailureCategory.server,
      ParseFailure() => FailureCategory.parse,
    };
  }

  bool get isRetryable {
    return switch (this) {
      NetworkFailure() => true,
      ServerFailure(:final statusCode) =>
        statusCode == 408 || statusCode == 429 || statusCode >= 500,
      ParseFailure() => false,
    };
  }

  Map<String, Object?> get telemetryData {
    return switch (this) {
      NetworkFailure() => {'failure_category': 'network'},
      ServerFailure(:final statusCode) => {
        'failure_category': 'server',
        'status_code': statusCode,
      },
      ParseFailure(:final cause) => {
        'failure_category': 'parse',
        'parse_error': cause.toString(),
      },
    };
  }
}
