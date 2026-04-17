import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pax_sdk/pax_sdk.dart';

class PrinterResult {
  const PrinterResult({
    required this.success,
    required this.backend,
    required this.message,
  });

  final bool success;
  final String backend;
  final String message;
}

class PrinterService {
  static const MethodChannel _channel = MethodChannel('com.example.pos_app');

  static Future<PrinterResult> testPrint() async {
    try {
      final now = DateTime.now().toString();
      final ok = await PaxSdk.initializePrinter();
      if (ok != true) {
        throw Exception('pax_sdk initializePrinter failed');
      }
      final dynamic res = await PaxSdk.printText(
        'POSEASE TEST PRINT\n$now',
        options: {'fontSize': 'large', 'alignment': 1},
      );
      if (_isSuccess(res)) {
        return const PrinterResult(
          success: true,
          backend: 'pax_sdk',
          message: 'Тест амжилттай хэвлэгдлээ (pax_sdk)',
        );
      }
      throw Exception('pax_sdk printText failed: $res');
    } catch (_) {
      try {
        final now = DateTime.now().toIso8601String();
        final native = await _channel.invokeMethod<String>(
          'android.epos.tasks.testPrint',
          {'text': 'POSEASE TEST PRINT\n$now'},
        );
        return PrinterResult(
          success: native == 'printed',
          backend: 'native',
          message: native == 'printed'
              ? 'Тест амжилттай хэвлэгдлээ (native)'
              : 'Тест хэвлэх хүсэлт илгээгдлээ (native)',
        );
      } catch (e) {
        return PrinterResult(
          success: false,
          backend: 'none',
          message: 'Тест хэвлэх алдаа: $e',
        );
      }
    }
  }

  static Future<PrinterResult> printReceiptImage(
    Uint8List pngBytes, {
    double? amount,
    String? dbRefNo,
    String? terminalPackage,
  }) async {
    try {
      final ok = await PaxSdk.initializePrinter();
      if (ok != true) {
        throw Exception('pax_sdk initializePrinter failed');
      }
      final dynamic res = await PaxSdk.printImage(
        pngBytes,
        options: {'alignment': 1},
      );
      if (_isSuccess(res)) {
        return const PrinterResult(
          success: true,
          backend: 'pax_sdk',
          message: 'Терминал дээр амжилттай хэвлэлээ (pax_sdk)',
        );
      }
      throw Exception('pax_sdk printImage failed: $res');
    } catch (_) {
      try {
        final base64Image = base64Encode(pngBytes);
        final args = <String, dynamic>{
          'base64': base64Image,
          // EPOS docs require amount > 0 and unique dbRefNo.
          'amount': (amount ?? 0).toStringAsFixed(2),
          'dbRefNo': (dbRefNo ?? DateTime.now().millisecondsSinceEpoch.toString())
              .trim(),
        };
        final pkg = terminalPackage?.trim();
        if (pkg != null && pkg.isNotEmpty) {
          args['packageName'] = pkg;
        }
        final epos = await _channel.invokeMethod<dynamic>(
          'android.epos.payment.printBitmap',
          args,
        );
        final ok = _isEposSuccess(epos);
        return PrinterResult(
          success: ok,
          backend: 'epos',
          message: ok
              ? 'Терминал дээр амжилттай хэвлэлээ (epos)'
              : 'EPOS хэвлэх хүсэлт илгээгдсэн боловч амжилтгүй: ${_eposMessage(epos)}',
        );
      } catch (_) {}
      try {
        final base64Image = base64Encode(pngBytes);
        final native = await _channel.invokeMethod<String>(
          'android.epos.tasks.printBitmap',
          {'base64': base64Image},
        );
        return PrinterResult(
          success: native == 'printed',
          backend: 'native',
          message: native == 'printed'
              ? 'Терминал дээр амжилттай хэвлэлээ (native)'
              : 'Хэвлэх хүсэлт илгээгдлээ (native)',
        );
      } catch (e) {
        return PrinterResult(
          success: false,
          backend: 'none',
          message: '$e',
        );
      }
    }
  }

  static bool _isEposSuccess(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final rspCode = (m['rspCode'] ?? '').toString().trim();
      final resultCode = m['resultCode'];
      if (rspCode == '000') return true;
      if (resultCode is num && resultCode == 1) return true;
    }
    return false;
  }

  static String _eposMessage(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final rspMsg = (m['rspMsg'] ?? '').toString().trim();
      if (rspMsg.isNotEmpty) return rspMsg;
      final error = (m['error'] ?? '').toString().trim();
      if (error.isNotEmpty) return error;
      final rspCode = (m['rspCode'] ?? '').toString().trim();
      if (rspCode.isNotEmpty) return 'rspCode=$rspCode';
    }
    return raw?.toString() ?? 'unknown';
  }

  static bool _isSuccess(dynamic res) {
    if (res == true) return true;
    if (res is Map) {
      final s = res['success'];
      if (s == true) return true;
      final status = (res['status'] ?? '').toString().toLowerCase();
      if (status == 'success' || status == 'ok' || status == 'printed') {
        return true;
      }
    }
    return false;
  }
}
