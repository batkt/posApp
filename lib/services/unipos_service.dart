import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/pos_native_debug_log.dart';
import 'pos_transaction_service.dart';

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

  /// Ensures a card-terminal round-trip actually succeeded before recording the sale.
  ///
  /// EPOS in-app returns `success` to Flutter even when [rspCode] is non-zero; it only
  /// sets [paymentType] when the transaction is OK. Previously, missing `paymentType`
  /// skipped validation and the sale was still posted as paid.
  ///
  /// [allowQpay] matches [CheckoutScreen], which permits terminal QPay; kiosk cashier
  /// uses `false` (card only).
  static void requireSuccessfulTerminalCardPayment(
    Map<String, dynamic>? terminal, {
    bool allowQpay = false,
  }) {
    if (terminal == null) {
      throw PosTransactionException(
        'Картын төлбөрийн хариу ирээгүй. Терминал дахин оролдоно уу.',
      );
    }
    final skipped = terminal['skipped'] == true;
    if (skipped) {
      throw PosTransactionException(
        'Картын төлбөр зөвхөн Android дээр терминалтай ажиллана.',
      );
    }

    if (terminal.containsKey('rspCode')) {
      final rsp = terminal['rspCode'];
      final ok = rsp == null ||
          rsp == 0 ||
          rsp.toString().trim() == '0' ||
          rsp.toString().trim() == '000';
      if (!ok) {
        final msg = terminal['rspMsg']?.toString().trim();
        final raw = msg != null && msg.isNotEmpty
            ? msg
            : 'Картын төлбөр амжилтгүй (${rsp?.toString() ?? ''}).';
        throw PosTransactionException(PosTransactionException.toUserMessage(raw));
      }
    }

    final paymentType =
        terminal['paymentType']?.toString().trim().toUpperCase();
    if (paymentType == null || paymentType.isEmpty) {
      throw PosTransactionException(
        'Картын төлбөр баталгаажсангүй. Дахин оролдоно уу.',
      );
    }

    final isCard = paymentType == 'CARD';
    final isQpay = paymentType == 'QPAY';
    if (!isCard && !(allowQpay && isQpay)) {
      throw PosTransactionException(
        allowQpay
            ? 'UniPOS төлбөр амжилтгүй: $paymentType'
            : 'Касс: зөвхөн карт. QPay хориотой. Төлбөр: $paymentType',
      );
    }
  }
}
