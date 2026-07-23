class AppCache {
  AppCache._();

  static final AppCache instance = AppCache._();

  final Map<String, dynamic> _store = {};
  final Set<String> _inFlight = {};
  final Map<String, Future<dynamic>> _inFlightFutures = {};

  bool has(String key) => _store.containsKey(key);

  T? get<T>(String key) => _store[key] as T?;

  void put<T>(String key, T value) {
    _store[key] = value;
  }

  /// Removes a single cached entry.
  void invalidate(String key) {
    _store.remove(key);
    _inFlight.remove(key);
    _inFlightFutures.remove(key);
  }

  void invalidateWhere(bool Function(String key) test) {
    _store.removeWhere((key, _) => test(key));
    _inFlight.removeWhere(test);
    _inFlightFutures.removeWhere((key, _) => test(key));
  }

  void invalidateAll() {
    _store.clear();
    _inFlight.clear();
    _inFlightFutures.clear();
  }

  Future<T> getOrFetch<T>(String key, Future<T> Function() fetcher) async {
    if (_store.containsKey(key)) return _store[key] as T;
    final existing = _inFlightFutures[key];
    if (existing != null) return await (existing as Future<T>);

    final future = fetcher();
    _inFlightFutures[key] = future;
    try {
      final result = await future;
      _store[key] = result;
      return result;
    } finally {
      _inFlightFutures.remove(key);
    }
  }

  void prefetch<T>(String key, Future<T> Function() fetcher) {
    if (_store.containsKey(key) || _inFlight.contains(key)) return;
    _inFlight.add(key);
    fetcher()
        .then((result) {
          _store[key] = result;
        })
        .catchError((_) {})
        .whenComplete(() => _inFlight.remove(key));
  }
}
