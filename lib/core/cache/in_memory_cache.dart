/// Gestor de caché en memoria genérico con TTL (Time-To-Live).
/// Encapsula la marca temporal de actualización y la política de caducidad
/// de instancias de tipo [T].
class InMemoryCache<T> {
  final Duration ttl;
  T? _data;
  DateTime? _lastUpdated;

  InMemoryCache({required this.ttl});

  /// Retorna los datos cacheados si aún no han expirado, o null si expiraron o no existen.
  T? get() {
    if (_data != null && _lastUpdated != null) {
      if (DateTime.now().difference(_lastUpdated!) < ttl) {
        return _data;
      }
    }
    return null;
  }

  /// Almacena un nuevo valor en el caché y refresca la marca temporal.
  void set(T value) {
    _data = value;
    _lastUpdated = DateTime.now();
  }

  /// Invalida manualmente el valor almacenado.
  void invalidate() {
    _data = null;
    _lastUpdated = null;
  }

  /// Indica si el caché contiene un valor válido y no expirado.
  bool get isValid => get() != null;
}
