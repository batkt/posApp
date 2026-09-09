import 'dart:async';

/// Хэрэглэгч тодорхой хугацаанд ямар ч үйлдэл хийхгүй бол [onTimeout]-г дуудна.
///
/// ПОС-ыг задгай орхиход хэн ч бусдын нэрээр борлуулалт хийх боломжтой байдаг
/// тул сешнийг автоматаар хаана. Тоолуур нь [registerActivity] бүрд эхнээсээ
/// эхэлдэг — жинхэнэ "идэвхгүй" хугацааг л хэмжинэ.
class InactivityMonitor {
  InactivityMonitor({
    required this.onTimeout,
    this.timeout = defaultTimeout,
  });

  /// Идэвхгүй байдлын хязгаар.
  static const Duration defaultTimeout = Duration(minutes: 15);

  final void Function() onTimeout;
  final Duration timeout;

  Timer? _timer;
  bool _started = false;

  /// Гаралт аль хэдийн хийгдсэн эсэх — нэг сешнд ХОЁР удаа гаргахгүй.
  bool _fired = false;

  bool get isRunning => _started && !_fired;

  void start() {
    _started = true;
    _fired = false;
    _restart();
  }

  /// Дурын хэрэглэгчийн үйлдэл (хүрэлт, товчлуур, гүйлгэлт) дээр дуудагдана.
  void registerActivity() {
    if (!isRunning) return;
    _restart();
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  void _restart() {
    _timer?.cancel();
    _timer = Timer(timeout, _fire);
  }

  void _fire() {
    if (_fired || !_started) return;
    _fired = true;
    _timer = null;
    onTimeout();
  }
}
