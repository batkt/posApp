import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode, kReleaseMode;
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pax_sdk/pax_sdk.dart';

class PrinterResult {
  const PrinterResult({
    required this.success,
    required this.backend,
    required this.message,
    this.data,
  });

  final bool success;
  final String backend;
  final String message;
  final Map<String, dynamic>? data;
}

class PrinterService {
  static const MethodChannel _channel = MethodChannel('mn.posease.mobile.terminal.pos');
  static const MethodChannel _paxChannel = MethodChannel('pax_sdk');

  /// Must match [MainActivity.kt] health-check JSON sent as [Intent.EXTRA_TEXT].
  static const String eposHealthCheckRequestJson =
      '{"category":"android.epos.payment.healthCheck"}';

  /// Full request + response for debugging / support (copy from UI).
  static String formatEposHealthCheckDebugText(PrinterResult res) {
    final b = StringBuffer()
      ..writeln('REQUEST (Intent.EXTRA_TEXT):')
      ..writeln(eposHealthCheckRequestJson)
      ..writeln()
      ..writeln('Flutter result:')
      ..writeln('  success: ${res.success}')
      ..writeln('  backend: ${res.backend}')
      ..writeln('  message: ${res.message}')
      ..writeln()
      ..writeln('RESPONSE (native map → Flutter):');
    if (res.data == null || res.data!.isEmpty) {
      b.writeln('(empty — check logcat MainActivity / EPOS app)');
    } else {
      try {
        final safe = _jsonEncodableValue(res.data) as Map<String, dynamic>;
        b.writeln(const JsonEncoder.withIndent('  ').convert(safe));
      } catch (e) {
        b.writeln(res.data.toString());
        b.writeln('(pretty-print failed: $e)');
      }
    }
    return b.toString();
  }

  /// Full dump for PAX test print (compare debug vs release APK on the same device).
  static String formatPaxTestPrintDebugText(PrinterResult res) {
    final b = StringBuffer()
      ..writeln('PAX test print / Neptune (pax_sdk) diagnostics')
      ..writeln(
        'If you see "q2.b.getInstance" (or similar): that is obfuscated NeptuneLite '
        'internals — NeptuneLiteUser.getInstance() / DAL failed (native .so, ROM, or R8). '
        'Compare pax_nativeLibraryProbe and initializePrinter_PlatformException. '
        'android/app/proguard-rules.pro keeps com.pax.** when minify is enabled.',
      )
      ..writeln()
      ..writeln('RESULT:')
      ..writeln('  success: ${res.success}')
      ..writeln('  backend: ${res.backend}')
      ..writeln('  message: ${res.message}')
      ..writeln();
    if (res.data == null || res.data!.isEmpty) {
      b.writeln('(no data map)');
    } else {
      try {
        final safe = _jsonEncodableValue(res.data) as Map<String, dynamic>;
        b.writeln(const JsonEncoder.withIndent('  ').convert(safe));
      } catch (e) {
        b.writeln(res.data.toString());
        b.writeln('(pretty-print failed: $e)');
      }
    }
    return b.toString();
  }

  static Future<Map<String, dynamic>> _paxTestPrintDiagnosticMeta() async {
    final m = <String, dynamic>{
      'buildMode': kReleaseMode
          ? 'release'
          : (kProfileMode ? 'profile' : 'debug'),
      'kDebugMode': kDebugMode,
    };
    try {
      final pi = await PackageInfo.fromPlatform();
      m['app'] = {
        'packageName': pi.packageName,
        'version': pi.version,
        'buildNumber': pi.buildNumber,
      };
    } catch (e) {
      m['packageInfoError'] = e.toString();
    }
    if (Platform.isAndroid) {
      try {
        final di = DeviceInfoPlugin();
        final a = await di.androidInfo;
        m['android'] = {
          'manufacturer': a.manufacturer,
          'model': a.model,
          'brand': a.brand,
          'device': a.device,
          'hardware': a.hardware,
          'product': a.product,
          'display': a.display,
          'sdkInt': a.version.sdkInt,
          'release': a.version.release,
          'securityPatch': a.version.securityPatch,
        };
      } catch (e) {
        m['androidDeviceError'] = e.toString();
      }
    } else {
      m['platform'] = Platform.operatingSystem;
    }
    return m;
  }

  static dynamic _jsonEncodableValue(dynamic v) {
    if (v == null) return null;
    if (v is num || v is String || v is bool) return v;
    if (v is Map) {
      return v.map(
        (k, val) => MapEntry(k.toString(), _jsonEncodableValue(val)),
      );
    }
    if (v is List) {
      return v.map(_jsonEncodableValue).toList();
    }
    return v.toString();
  }

  static Future<PrinterResult> testPrint() async {
    final data = await _paxTestPrintDiagnosticMeta();
    final now = DateTime.now().toString();
    final lines = 'POSEASE TEST PRINT\n$now';

    try {
      try {
        final probe = await PaxSdk.testNativeLibraryLoading();
        data['pax_nativeLibraryProbe'] = probe;
      } catch (e) {
        data['pax_nativeLibraryProbe_error'] = e.toString();
      }

      final pax = <String, dynamic>{};
      data['pax'] = pax;
      pax['printText_lines'] = lines;

      var paxInitOk = false;
      try {
        final init = await _paxChannel.invokeMethod<dynamic>('initializePrinter');
        pax['initializePrinter_result'] = init;
        paxInitOk = init == true;
      } on PlatformException catch (e) {
        pax['initializePrinter_PlatformException'] = {
          'code': e.code,
          'message': e.message,
          'details': e.details,
        };
      }
      if (!paxInitOk) {
        throw StateError(
          pax['initializePrinter_PlatformException'] != null
              ? 'initializePrinter failed (see initializePrinter_PlatformException)'
              : 'initializePrinter returned non-true (see initializePrinter_result)',
        );
      }

      final dynamic res = await PaxSdk.printText(
        lines,
        options: {'fontSize': 'large', 'alignment': 1},
      );
      pax['printText_raw'] = res;
      if (_isSuccess(res)) {
        return PrinterResult(
          success: true,
          backend: 'pax_sdk',
          message: 'Тест амжилттай хэвлэгдлээ (pax_sdk)',
          data: data,
        );
      }
      pax['printText_notAccepted'] = true;
      throw StateError('printText response not success: $res');
    } catch (e, st) {
      data['pax_exception'] = e.toString();
      data['pax_stack'] = st.toString();
    }

    try {
      final iso = DateTime.now().toIso8601String();
      final fb = <String, dynamic>{'text': 'POSEASE TEST PRINT\n$iso'};
      data['fallback'] = fb;
      final native = await _channel.invokeMethod<dynamic>(
        'android.epos.tasks.testPrint',
        fb,
      );
      fb['android_epos_tasks_testPrint_raw'] = native;
      final eposOk = _isEposSuccess(native);
      if (eposOk) {
        return PrinterResult(
          success: true,
          backend: 'epos',
          message: 'Тест амжилттай хэвлэгдлээ (epos)',
          data: data,
        );
      }
      if (native is Map) {
        return PrinterResult(
          success: false,
          backend: 'epos',
          message: 'EPOS тест хэвлэх амжилтгүй: ${_eposMessage(native)}',
          data: data,
        );
      }
      final okNative = native == 'printed';
      return PrinterResult(
        success: okNative,
        backend: 'native',
        message: okNative
            ? 'Тест амжилттай хэвлэгдлээ (native)'
            : 'Тест хэвлэх хүсэлт илгээгдлээ (native)',
        data: data,
      );
    } catch (e, st) {
      data['fallback_exception'] = e.toString();
      data['fallback_stack'] = st.toString();
      return PrinterResult(
        success: false,
        backend: 'none',
        message: 'Тест хэвлэх алдаа: $e',
        data: data,
      );
    }
  }

  static Future<PrinterResult> performEposHealthCheck({
    String? terminalPackage,
  }) async {
    try {
      final args = <String, dynamic>{};
      final pkg = terminalPackage?.trim();
      if (pkg != null && pkg.isNotEmpty) {
        args['packageName'] = pkg;
      }
      final epos = await _channel.invokeMethod<dynamic>(
        'android.epos.payment.healthCheck',
        args,
      );
      final ok = _isEposSuccess(epos);
      final resData = epos is Map ? Map<String, dynamic>.from(epos) : null;
      return PrinterResult(
        success: ok,
        backend: 'epos',
        data: resData,
        message: ok
            ? 'EPOS холболт амжилттай'
            : 'EPOS холболт амжилтгүй: ${_eposMessage(epos)}',
      );
    } catch (e) {
      return PrinterResult(
        success: false,
        backend: 'epos',
        message: 'EPOS алдаа: $e',
      );
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
      // EPOS SEND first (shared with many terminals); then direct Neptune bitmap on device.
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
        final resData = epos is Map ? Map<String, dynamic>.from(epos) : null;
        return PrinterResult(
          success: ok,
          backend: 'epos',
          data: resData,
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

  /// EPOS [BaseResponse] often puts business fields inside [jsonRet] (string or map).
  static Map<String, dynamic> _eposMergedMap(dynamic raw) {
    if (raw is! Map) return {};
    final m = Map<String, dynamic>.from(raw);
    final jr = m['jsonRet'];
    if (jr is String && jr.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(jr);
        if (decoded is Map) {
          m.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    } else if (jr is Map) {
      m.addAll(Map<String, dynamic>.from(jr));
    }
    return m;
  }

  static bool _isEposSuccess(dynamic raw) {
    final m = _eposMergedMap(raw);
    if (m.isEmpty) return false;
    final rspCode = (m['rspCode'] ?? '').toString().trim();
    final resultCode = m['resultCode'];
    if (rspCode == '000') return true;
    if (resultCode is num && resultCode == 1) return true;
    return false;
  }

  static String _eposMessage(dynamic raw) {
    final m = _eposMergedMap(raw);
    if (m.isNotEmpty) {
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
