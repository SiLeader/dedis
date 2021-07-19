abstract class KeysCommands<K, V> {
  Future<bool> del(K key);
  Future<bool> exists(K key);
  Future<bool> expire(K key, Duration duration);
  Future<List<String>> keys(String pattern);

  Future<V?> get(K key);
  Future<bool> set(K key, V value);
}

abstract class ListCommands<K, V> {
  Future<List<V>> lrange(K key, int startIndex, int endIndex);
  Future<bool> rpush(K key, V value);
}

abstract class TransactionCommands<K, V> {
  Future<void> multi();
  Future<void> exec();
}

abstract class PubSubCommands<V> {
  Stream<V> psubscribe(String pattern);
  Future<int?> publish(String channel, V message);
}
