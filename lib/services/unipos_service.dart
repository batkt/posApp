import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/pos_native_debug_log.dart';

class UniPosService {
  UniPosService._();

  static const MethodChannel _channel = MethodChannel('mn.posease.mobile.terminal.pos');

  static Future<Map<String, dynamic>?> purchase({
    required double amount,
    String code = 'NormalPurchase',
    int originalId = 0,
    /// Android applicationId of the bank terminal app when it is not `mn.genesis.unipos.terminal`.
    String? terminalPackage,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {'skipped': true, 'reason': 'not_android'};
    }
    final args = <String, dynamic>{
      'amount': amount,
      'code': code,
      'originalId': originalId,
    };
    final pkg = terminalPackage?.trim();
    if (pkg != null && pkg.isNotEmpty) {
      args['packageName'] = pkg;
    }
    try {
      PosNativeDebugLog.record(
        'UniPos',
        'android.unipos.purchase request',
        <String, Object?>{'amount': amount, 'code': code, 'package': pkg},
      );
      final raw = await _channel.invokeMethod<dynamic>(
        'android.unipos.purchase',
        args,
      );
      final parsed = _parseResult(raw);
      PosNativeDebugLog.record('UniPos', 'android.unipos.purchase response', parsed);
      return parsed;
    } on PlatformException catch (e, st) {
      PosNativeDebugLog.record(
        'UniPos',
        'android.unipos.purchase PlatformException',
        <String, Object?>{
          'code': e.code,
          'message': e.message,
          'details': e.details,
          'stack': st.toString(),
        },
      );
      rethrow;
    } catch (e, st) {
      PosNativeDebugLog.record(
        'UniPos',
        'android.unipos.purchase error',
        '$e\n$st',
      );
      rethrow;
    }
  }

  static Map<String, dynamic>? _parseResult(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return {'raw': raw.toString()};
    final map = Map<String, dynamic>.from(raw);
    final resultString = map['result']?.toString();
    if (resultString != null && resultString.trim().isNotEmpty) {
      try {
        map['resultJson'] = jsonDecode(resultString);
      } catch (_) {}
    }
    return map;
  }
}
