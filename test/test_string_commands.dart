import 'package:dedis/dedis.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final cli = await RedisClient.connect('localhost', 6379, db: 1);
  final com = cli.getCommands<String, String>();

  test('set and get', () async {
    expect(await com.set('key', 'value'), isTrue);
    expect(await com.get('key'), isNotNull);
  });
}
