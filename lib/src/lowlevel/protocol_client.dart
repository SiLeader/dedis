import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dedis/src/exception.dart';
import 'package:dedis/src/lowlevel/resp.dart';

class RedisProtocolClient {
  final Socket _socket;
  final Queue<Completer<Resp>> _waitingCompleter = ListQueue<Completer<Resp>>();
  final Stream<List<int>> _stream;

  RedisProtocolClient._(this._socket) : _stream = _socket.asBroadcastStream() {
    _stream.listen(_onData);
  }

  static Future<RedisProtocolClient> createConnection({
    required String host,
    required int port,
  }) async {
    final sock = await Socket.connect(host, port)
      ..setOption(SocketOption.tcpNoDelay, true);
    return RedisProtocolClient._(sock);
  }

  void _onData(List<int> data) {
    final str = utf8.decode(data);
    if (_waitingCompleter.isEmpty) {
      return;
    }
    final f = _waitingCompleter.removeFirst();
    final resp = Resp.deserialize(str);
    if (resp == null) {
      f.completeError(RedisConvertException('failed to convert'));
      return;
    }
    f.complete(resp);
  }

  void sendCommand(Resp resp) {
    _socket.add(utf8.encode(resp.serialize()));
  }

  Future<Resp> receive() {
    final c = Completer<Resp>();
    _waitingCompleter.addLast(c);
    return c.future;
  }

  Stream<Resp?> get stream => _stream
      .map((event) => utf8.decode(event))
      .map((event) => Resp.deserialize(event));

  Future<void> close() => _socket.close();
}
