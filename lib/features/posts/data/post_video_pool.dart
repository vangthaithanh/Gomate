/// View-scoped native decoders only. No files, URLs or permission decisions.
class PostVideoPool {
  final int capacity;
  PostVideoPool({this.capacity = 2});
  bool get hasRoom => _release.length < capacity;
  final _release = <Object, void Function()>{};
  void acquire(Object key, void Function() release) {
    _release.remove(key);
    _release[key] = release;
    while (_release.length > capacity) {
      final first = _release.keys.first;
      _release.remove(first)?.call();
    }
  }

  void forget(Object key) => _release.remove(key);
  void clear() {
    final callbacks = _release.values.toList();
    _release.clear();
    for (final release in callbacks) {
      release();
    }
  }
}
