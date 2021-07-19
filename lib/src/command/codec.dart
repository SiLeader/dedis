import 'dart:convert';

abstract class RedisConverter<S, D> extends Converter<S, D> {
  bool isSupporting<U>(dynamic value) => value is S && U == D;
}

typedef RedisEncoder<T> = RedisConverter<T, String>;

typedef RedisDecoder<T> = RedisConverter<String, T>;

class RedisCodec<T> {
  final RedisEncoder<T> encoder;
  final RedisDecoder<T> decoder;

  RedisCodec({
    required this.encoder,
    required this.decoder,
  });
}

class StringEncoder extends RedisEncoder<String> {
  @override
  String convert(String input) => input;
}

class StringDecoder extends RedisDecoder<String> {
  @override
  String convert(String input) => input;
}

class IntEncoder extends RedisEncoder<int> {
  @override
  String convert(int input) => input.toString();
}

class IntDecoder extends RedisDecoder<int> {
  @override
  int convert(String input) => int.parse(input);
}
