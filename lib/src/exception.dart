class RedisException implements Exception {
  final String message;

  const RedisException(this.message);

  @override
  String toString() => 'RedisException: $message';
}

class RedisConvertException extends RedisException {
  const RedisConvertException(String message)
      : super('convert error: $message');
}
