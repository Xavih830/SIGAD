class InMemoryCache<T> {
  final Duration ttl;
  T? _data;
  DateTime? _lastUpdated;

  InMemoryCache({required this.ttl});

  T? get() {
    if (_data != null && _lastUpdated != null) {
      if (DateTime.now().difference(_lastUpdated!) < ttl) {
        return _data;
      }
    }
    return null;
  }

  void set(T value) {
    _data = value;
    _lastUpdated = DateTime.now();
  }

  void invalidate() {
    _data = null;
    _lastUpdated = null;
  }

  bool get isValid => get() != null;
}
