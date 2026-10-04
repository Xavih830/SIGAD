import 'dart:async';

class SessionEvents {
  static final StreamController<void> _expired = StreamController<void>.broadcast();
  static Stream<void> get onExpired => _expired.stream;
  static void notifyExpired() => _expired.add(null);
}
