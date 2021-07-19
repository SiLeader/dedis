import 'package:dedis/src/exception.dart';

class RedisError {
  final String prefix;
  final String message;

  RedisError({required this.prefix, required this.message});

  @override
  String toString() => '$prefix: $message';
}

enum RespType {
  STRING,
  ARRAY,
  INTEGER,
  ERROR,
  NULL,
  UNKNOWN,
}

class Resp {
  static const _CRLF = '\u000d\u000a';

  final dynamic value;

  Resp(this.value);

  String _serializeValue(dynamic value, {bool isBulkString = true}) {
    if (value is String) {
      if (!isBulkString && !value.contains(RegExp('\s'))) {
        return '+$value$_CRLF';
      }
      return '\$${value.length}$_CRLF$value$_CRLF';
    }
    if (value is int) {
      return ':$value$_CRLF';
    }

    if (value is List) {
      final data = [
        '*${value.length}$_CRLF',
        ...value.map((e) => _serializeValue(e, isBulkString: true))
      ].join('');
      return data;
    }
    return '';
  }

  String serialize() => _serializeValue(value);

  static Resp? deserialize(String s) =>
      _deserializeEntry(s.split(_CRLF), 0)?.resp;

  RespType get type {
    if (value == null) {
      return RespType.NULL;
    }
    if (value is String) {
      return RespType.STRING;
    }
    if (value is List) {
      return RespType.ARRAY;
    }
    if (value is int) {
      return RespType.INTEGER;
    }
    if (value is RedisError) {
      return RespType.ERROR;
    }
    return RespType.UNKNOWN;
  }

  bool get isNull => type == RespType.NULL;
  bool get isString => type == RespType.STRING;
  bool get isList => type == RespType.ARRAY;
  bool get isInteger => type == RespType.INTEGER;
  bool get isError => type == RespType.ERROR;

  String? get stringValue => isString ? value as String : null;
  List<dynamic>? get arrayValue => isList ? value as List : null;
  int? get integerValue => isInteger ? value as int : null;
  RedisError? get errorValue => isError ? value as RedisError : null;

  void throwIfError() {
    final err = errorValue;
    if (err == null) {
      return;
    }
    throw RedisException('$err');
  }

  @override
  String toString() => '$stringValue $arrayValue $integerValue $errorValue';
}

class _DeserializeResult {
  final int endIndex;
  final dynamic value;

  _DeserializeResult(this.endIndex, this.value);

  Resp get resp => Resp(value);
}

extension _SafeAt on List<String> {
  String? safeAt(int index) => index < length ? this[index] : null;
}

extension _ToInt on String {
  int? toInt() => int.tryParse(this);
}

_DeserializeResult? _deserializeEntry(List<String> s, int startIndex) {
  final current = s.safeAt(startIndex);
  if (current == null) {
    return null;
  }

  switch (current[0]) {
    case '+': // simple strings
      return _deserializeSimpleString(s, startIndex);
    case '-': // errors
      return _deserializeError(s, startIndex);
    case ':': // integers
      return _deserializeInteger(s, startIndex);
    case '\$': // bulk strings
      return _deserializeBulkString(s, startIndex);
    case '*': // arrays
      return _deserializeArray(s, startIndex);
  }

  return null;
}

_DeserializeResult? _deserializeSimpleString(List<String> s, int startIndex) {
  final value = s.safeAt(startIndex)?.substring(1);
  if (value == null) {
    return null;
  }
  return _DeserializeResult(startIndex + 1, value);
}

_DeserializeResult? _deserializeBulkString(List<String> s, int startIndex) {
  final lengthStr = s.safeAt(startIndex);
  if (lengthStr == null) {
    return null;
  }

  final length = lengthStr.substring(1).toInt();

  if (length == null) {
    return null;
  }
  if (length == -1) {
    return _DeserializeResult(startIndex + 1, null);
  }
  if (length < 0) {
    return null;
  }
  final value = s.sublist(startIndex + 1).join(Resp._CRLF).substring(0, length);

  return _DeserializeResult(
    startIndex + value.split(Resp._CRLF).length + 1,
    value,
  );
}

_DeserializeResult? _deserializeError(List<String> s, int startIndex) {
  final value = s.safeAt(startIndex)?.substring(1);
  if (value == null) {
    return null;
  }
  final spl = value.split(' ');
  final prefix = spl[0];
  final message = spl.sublist(1).join(' ');

  return _DeserializeResult(
    startIndex + 1,
    RedisError(
      prefix: prefix,
      message: message,
    ),
  );
}

_DeserializeResult? _deserializeInteger(List<String> s, int startIndex) {
  final value = s.safeAt(startIndex)?.substring(1).toInt();
  if (value == null) {
    return null;
  }
  return _DeserializeResult(startIndex + 1, value);
}

_DeserializeResult? _deserializeArray(List<String> s, int startIndex) {
  final lengthStr = s.safeAt(startIndex);
  if (lengthStr == null) {
    return null;
  }

  final length = lengthStr.substring(1).toInt();

  if (length == null) {
    return null;
  }
  if (length == -1) {
    return _DeserializeResult(startIndex + 1, null);
  }
  if (length < 0) {
    return null;
  }
  final list = [];
  var index = startIndex + 1;
  for (var i = 0; i < length; ++i) {
    final res = _deserializeEntry(s, index);
    if (res == null) {
      return null;
    }
    list.add(res.value);
    index = res.endIndex;
  }

  return _DeserializeResult(index, list);
}
