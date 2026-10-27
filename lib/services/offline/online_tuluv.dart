import 'dart:async';
import 'dart:io' show SocketException, HandshakeException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_service.dart';

/// Сервертэй холбогдож байгаа эсэхийг нэг газар хянана.
///
/// Төхөөрөмж Wi-Fi-д холбогдсон ч интернэт/сервер унасан байж болох тул
/// серверийн `/ping`-ийг тогтмол шалгаж, бодит хүсэлт сүлжээний алдаагаар
/// унасан даруйд [holboltTasarsan] дуудагдаж офлайн болно.
class OnlineTuluv extends ChangeNotifier {
  OnlineTuluv._();
  static final OnlineTuluv instance = OnlineTuluv._();

  static const Duration _onlinePing = Duration(seconds: 20);
  static const Duration _offlinePing = Duration(seconds: 5);
  static const Duration _pingTimeout = Duration(seconds: 4);

  bool _online = true;
  bool get online => _online;

  Timer? _timer;
  bool _ekhelsen = false;
  final http.Client _http = http.Client();

  void ekhluulekh() {
    if (_ekhelsen) return;
    _ekhelsen = true;
    unawaited(shalgakh());
  }

  void _tuluvSolikh(bool shine) {
    if (_online != shine) {
      _online = shine;
      notifyListeners();
    }
    _dakhinTovlokh();
  }

  void _dakhinTovlokh() {
    _timer?.cancel();
    _timer = Timer(_online ? _onlinePing : _offlinePing, () {
      unawaited(shalgakh());
    });
  }

  /// Серверийг шууд шалгана — үр дүнг буцаана.
  Future<bool> shalgakh() async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.posBaseUrl}/ping?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final res = await _http.get(uri).timeout(_pingTimeout);
      // Сервер ямар нэг хариу өгсөн бол (404 ч гэсэн — /ping-гүй хуучин
      // backend) холбогдож байна. Зөвхөн 5xx (nginx: backend унасан) офлайн.
      final ok = res.statusCode < 500;
      _tuluvSolikh(ok);
      return ok;
    } catch (_) {
      _tuluvSolikh(false);
      return false;
    }
  }

  /// Бодит хүсэлт серверт хүрч чадаагүй үед.
  void holboltTasarsan() {
    _ekhelsen = true;
    _tuluvSolikh(false);
  }

  /// Алдаа нь серверт хүрч чадаагүйгээс (хариугүй) үүссэн эсэх.
  /// Сервер хариу өгсөн (4xx/5xx) алдаа энд хамаарахгүй.
  static bool holboltiinAldaaEsekh(Object e) {
    if (e is TimeoutException || e is http.ClientException) return true;
    if (!kIsWeb && (e is SocketException || e is HandshakeException)) {
      return true;
    }
    final t = e.toString().toLowerCase();
    return t.contains('socketexception') ||
        t.contains('failed host lookup') ||
        t.contains('connection refused') ||
        t.contains('connection closed') ||
        t.contains('network is unreachable') ||
        t.contains('xmlhttprequest error') ||
        t.contains('timeoutexception');
  }
}
