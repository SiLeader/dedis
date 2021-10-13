import 'dart:async';

import 'package:dedis/dedis.dart';

Future<void> main() async {
  final cli = await RedisClient.connect('localhost', 6379, db: 1);
  final com = cli.getCommands<String, String>();

  print(await com.keys('*'));

  print('set get exists');
  print(await com.set('key', 'value1'));
  print(await com.get('key'));
  print(await com.exists('key'));

  print('set get exists');
  print(await com.set('key', 'value2'));
  print(await com.get('key'));
  print(await com.exists('key'));

  print('get del exists');
  print(await com.del('key'));
  print(await com.get('key'));
  print(await com.exists('key'));

  print('set set set set keys keys');
  print(await com.set('key', 'value'));
  print(await com.set('key2', 'value'));
  print(await com.set('key3', 'value'));
  print(await com.set('key4', 'value'));
  print(await com.keys('*'));
  print(await com.keys('key*'));

  print('set expire exists exists');
  print(await com.set('key', 'value'));
  print(await com.expire('key', Duration(seconds: 1)));
  print(await com.exists('key'));
  await Future.delayed(Duration(seconds: 1));
  print(await com.exists('key'));

  print('lpush lrange lpush lrange rpush lset');
  print(await com.lpush('list_key', ['value1']));
  print(await com.lrange('list_key', 0, -1));
  print(await com.lpush('list_key', ['value l1']));
  print(await com.lrange('list_key', 0, -1));
  print(await com.rpush('list_key', ['value r1']));
  print(await com.lset('list_key', 1, 'value2'));

  print('pubsub');
  final psCli = await RedisClient.connect('localhost', 6379, db: 1);
  final PubSubCommands<String> psCom = psCli.getCommands<String, String>();
  unawaited(psCom.psubscribe('/test/*').forEach((element) {
    print('psubscribe: $element');
  }));

  print(await com.publish('/test/1', 'message/1'));
  print(await com.publish('/test/2', 'message/2'));
  print(await com.publish('/test/3', 'message/3'));
  print(await com.publish('/test1/1', 'message1/1'));

  await cli.close();
  await psCli.close();
}
