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
