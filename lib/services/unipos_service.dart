import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class UniPosService {
  UniPosService._();

  static const MethodChannel _channel = MethodChannel('com.example.pos_app');

  static Future<Map<String, dynamic>?> purchase({
    required double amount,
    String code = 'NormalPurchase',
    int originalId = 0,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {'skipped': true, 'reason': 'not_android'};
    }
    final raw = await _channel.invokeMethod<dynamic>('android.unipos.purchase', {
      'amount': amount,
      'code': code,
      'originalId': originalId,
    });
    return _parseResult(raw);
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
