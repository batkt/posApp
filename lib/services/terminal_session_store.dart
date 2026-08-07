import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the terminal (kiosk) login session so a process restarted by
/// [BackgroundWatchdogService] — or Android itself after a reboot — can restore
/// an authenticated session without a human re-typing credentials. Scoped to
/// terminal devices only; phone/mobile logins never call [persist].
class TerminalSessionStore {
  TerminalSessionStore._();
  static final TerminalSessionStore instance = TerminalSessionStore._();

  static const _key = 'terminal_auto_session_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> persist({
    required String token,
    required String baiguullagiinId,
    required String salbariinId,
    required Map<String, dynamic> ajiltan,
  }) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'token': token,
          'baiguullagiinId': baiguullagiinId,
          'salbariinId': salbariinId,
          'ajiltan': ajiltan,
        }),
      );
      debugPrint('>>> [TerminalSessionStore] persisted session for salbariinId=$salbariinId');
    } catch (e) {
      // Ignore — terminal falls back to a normal manual login next start.
      debugPrint('>>> [TerminalSessionStore] persist failed: $e');
    }
  }

  /// Returns `{token, baiguullagiinId, salbariinId, ajiltan}`, or null if
  /// nothing was ever persisted (phone install, or terminal pre-first-login).
  Future<Map<String, dynamic>?> restore() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        debugPrint('>>> [TerminalSessionStore] restore: nothing persisted');
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('>>> [TerminalSessionStore] restore failed: $e');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
