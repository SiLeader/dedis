import 'package:dedis/src/exception.dart';
import 'package:dedis/src/lowlevel/protocol_client.dart';
import 'package:dedis/src/lowlevel/resp.dart';

import 'codec.dart';
import 'commands.dart';

class _MultiCodec {
  final List<RedisCodec> codecs = [
    RedisCodec(encoder: StringEncoder(), decoder: StringDecoder()),
    RedisCodec(encoder: IntEncoder(), decoder: IntDecoder()),
  ];

  String encode<T>(T value) {
    for (final e in codecs) {
      if (e.encoder.isSupporting<T>(value)) {
        return e.encoder.convert(value);
      }
    }
    throw RedisConvertException('no encoder found');
  }

  T decode<T>(String value) {
    for (final e in codecs) {
      if (e.decoder.isSupporting<T>(value)) {
        return e.decoder.convert(value);
      }
    }
    throw RedisConvertException('no decoder found');
  }

  void registerCodec(RedisCodec codec) {
    codecs.add(codec);
  }
}

abstract class Commands<K, V>
    implements
        KeysCommands<K, V>,
        ListCommands<K, V>,
        TransactionCommands<K, V>,
        PubSubCommands<V> {}

class CommandsClient<K, V> implements Commands<K, V> {
  final RedisProtocolClient _connection;
  CommandsClient._(this._connection);

  final _MultiCodec keyCodec = _MultiCodec();
  final _MultiCodec valueCodec = _MultiCodec();

  @override
  Future<bool> del(K key) async {
    final keyString = keyCodec.encode<K>(key);
    _connection.sendCommand(Resp(['DEL', keyString]));
    final res = await _connection.receive();
    res.throwIfError();

    return res.isInteger && res.integerValue == 1;
  }

  @override
  Future<bool> exists(K key) async {
    final keyString = keyCodec.encode<K>(key);
    _connection.sendCommand(Resp(['EXISTS', keyString]));
    final res = await _connection.receive();
    res.throwIfError();

    return res.isInteger && res.integerValue == 1;
  }

  @override
  Future<bool> expire(K key, Duration duration) async {
    final keyString = keyCodec.encode<K>(key);
    _connection
        .sendCommand(Resp(['EXPIRE', keyString, '${duration.inSeconds}']));
    final res = await _connection.receive();
    res.throwIfError();

    return res.isInteger && res.integerValue == 1;
  }

  @override
  Future<V?> get(K key) async {
    final keyString = keyCodec.encode<K>(key);
    _connection.sendCommand(Resp(['GET', keyString]));
    final res = await _connection.receive();
    res.throwIfError();

    final str = res.stringValue;
    if (str == null) {
      return null;
    }
    return valueCodec.decode<V>(str);
  }

  @override
  Future<List<String>> keys(String pattern) async {
    _connection.sendCommand(Resp(['KEYS', pattern]));
    final res = await _connection.receive();
    res.throwIfError();

    final l = res.arrayValue;
    if (l == null) {
      return [];
    }
    return l.map((e) => e.toString()).toList();
  }

  @override
  Future<bool> set(K key, V value) async {
    final keyString = keyCodec.encode<K>(key);
    final valueString = valueCodec.encode<V>(value);
    _connection.sendCommand(Resp(['SET', keyString, valueString]));
    final res = await _connection.receive();
    res.throwIfError();

    final s = res.stringValue;
    if (s == null) {
      return false;
    }
    return s == 'OK';
  }

  @override
  Future<List<V>> lrange(K key, int startIndex, int endIndex) async {
    final keyString = keyCodec.encode<K>(key);
    _connection.sendCommand(Resp(
        ['LRANGE', keyString, startIndex.toString(), endIndex.toString()]));
    final res = await _connection.receive();
    res.throwIfError();

    final l = res.arrayValue;
    if (l == null) {
      return [];
    }

    return l.map((e) => valueCodec.decode<V>(e)).toList();
  }

  @override
  Future<bool> rpush(K key, List<V> values) async {
    final keyString = keyCodec.encode<K>(key);
    final command = ['RPUSH', keyString];
    command.addAll(values.map((e) => valueCodec.encode<V>(e)));

    _connection.sendCommand(Resp(command));
    final res = await _connection.receive();
    res.throwIfError();

    return res.isInteger;
  }

  @override
  Future<bool> lpush(K key, List<V> values) async {
    final keyString = keyCodec.encode<K>(key);
    final command = ['LPUSH', keyString];
    command.addAll(values.map((e) => valueCodec.encode<V>(e)));

    _connection.sendCommand(Resp(command));
    final res = await _connection.receive();
    res.throwIfError();

    return res.isInteger;
  }

  @override
  Future<bool> lset(K key, int index, V value) async {
    final keyString = keyCodec.encode<K>(key);
    final valueString = valueCodec.encode<V>(value);
    _connection
        .sendCommand(Resp(['LSET', keyString, index.toString(), valueString]));
    final res = await _connection.receive();
    res.throwIfError();

    return res.stringValue == 'OK';
  }

  @override
  Future<void> exec() async {
    _connection.sendCommand(Resp(['MULTI']));
    await _connection.receive();
  }

  @override
  Future<void> multi() async {
    _connection.sendCommand(Resp(['MULTI']));
    await _connection.receive();
  }

  @override
  Stream<V> psubscribe(String pattern) {
    _connection.sendCommand(Resp(['PSUBSCRIBE', pattern]));
    return _connection.stream
        .map((event) => event?.arrayValue)
        .where((event) => event != null)
        .map((event) => event!)
        .map((event) => valueCodec.decode(event.last));
  }

  @override
  Future<int?> publish(String channel, V message) async {
    final messageString = valueCodec.encode<V>(message);

    _connection.sendCommand(Resp(['PUBLISH', channel, messageString]));
    final res = await _connection.receive();
    return res.integerValue;
  }
}

class RedisClient {
  final RedisProtocolClient _connection;

  RedisClient._(this._connection);

  static Future<RedisClient> connect(
    String host,
    int port, {
    required int db,
  }) async {
    final rpc =
        await RedisProtocolClient.createConnection(host: host, port: port);
    rpc.sendCommand(Resp(['SELECT', '$db']));
    return RedisClient._(rpc);
  }

  CommandsClient<K, V> getCommands<K, V>() =>
      CommandsClient<K, V>._(_connection);

  Future<void> close() => _connection.close();
}
