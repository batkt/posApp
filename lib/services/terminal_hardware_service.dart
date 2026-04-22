import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/pos_native_debug_log.dart';

/// Native-reported hardware + SDK routing (see [TerminalProfile] on Android).
enum TerminalHardwareKind {
  eposOpenInApp,
  neptunePax,
  legacyIntent,
  unknown,
}

class TerminalHardwareInfo {
  const TerminalHardwareInfo({
    required this.kind,
    required this.model,
    required this.device,
    required this.manufacturer,
    required this.product,
    required this.eposInAppReady,
  });

  final TerminalHardwareKind kind;
  final String model;
  final String device;
  final String manufacturer;
  final String product;
  final bool eposInAppReady;

  /// PAX A930 / A8900 with EPOS Open JAR active in MainActivity.
  bool get usesEposOpenInApp =>
      kind == TerminalHardwareKind.eposOpenInApp && eposInAppReady;

  static const MethodChannel _ch = MethodChannel('com.example.pos_app');

  static TerminalHardwareInfo? _cached;

  static TerminalHardwareInfo _fromProfileMap(Map<String, dynamic> map) {
    final p = map['profile']?.toString() ?? '';
    TerminalHardwareKind k = TerminalHardwareKind.unknown;
    if (p == 'EPOS_OPEN_IN_APP') {
      k = TerminalHardwareKind.eposOpenInApp;
    } else if (p == 'NEPTUNE_PAX') {
      k = TerminalHardwareKind.neptunePax;
    } else if (p == 'LEGACY_INTENT') {
      k = TerminalHardwareKind.legacyIntent;
    }
    return TerminalHardwareInfo(
      kind: k,
      model: map['model']?.toString() ?? '',
      device: map['device']?.toString() ?? '',
      manufacturer: map['manufacturer']?.toString() ?? '',
      product: map['product']?.toString() ?? '',
      eposInAppReady: map['eposInAppReady'] == true,
    );
  }

  static const TerminalHardwareInfo _unknownNonAndroid =
      TerminalHardwareInfo(
    kind: TerminalHardwareKind.unknown,
    model: '',
    device: '',
    manufacturer: '',
    product: '',
    eposInAppReady: false,
  );

  /// One native read; sets [_cached] on success or fallback.
  static Future<
      ({
        TerminalHardwareInfo info,
        Map<String, dynamic> raw,
        String? channelError,
      })> _readNativeOnce() async {
    if (kIsWeb || !Platform.isAndroid) {
      _cached = _unknownNonAndroid;
      return (
        info: _cached!,
        raw: <String, dynamic>{
          'note': 'terminal.hardwareProfile is Android-only',
        },
        channelError: null,
      );
    }
    try {
      final raw = await _ch.invokeMethod<dynamic>('terminal.hardwareProfile');
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{'_unparsed': '$raw'};
      _cached = _fromProfileMap(map);
      return (info: _cached!, raw: map, channelError: null);
    } catch (e) {
      _cached = _unknownNonAndroid;
      return (info: _cached!, raw: <String, dynamic>{}, channelError: '$e');
    }
  }

  static Future<TerminalHardwareInfo> probe() async {
    if (_cached != null) return _cached!;
    final snap = await _readNativeOnce();
    return snap.info;
  }

  /// For tests / hot-restart when native profile changes.
  static void clearCache() => _cached = null;

  /// Read-only support text: fresh `terminal.hardwareProfile`, parsed flags,
  /// Flutter build mode, and [PosNativeDebugLog] (past bridge responses only).
  /// Does **not** open EPOS, UniPOS, or run health check / print.
  static Future<String> buildRoutingDebugReport() async {
    clearCache();
    final snap = await _readNativeOnce();
    final buf = StringBuffer();
    buf.writeln(
      'PosEase — terminal routing snapshot (no EPOS / UniPOS invoked)\n',
    );
    if (snap.channelError != null) {
      buf.writeln('MethodChannel error: ${snap.channelError}\n');
    }
    buf.writeln('=== terminal.hardwareProfile (raw) ===');
    try {
      buf.writeln(const JsonEncoder.withIndent('  ').convert(snap.raw));
    } catch (e) {
      buf.writeln('(encode error: $e)\n${snap.raw}');
    }
    buf.writeln();
    buf.writeln('=== Parsed (Dart) ===');
    buf.writeln('kind: ${snap.info.kind.name}');
    buf.writeln('usesEposOpenInApp: ${snap.info.usesEposOpenInApp}');
    buf.writeln('model: ${snap.info.model}');
    buf.writeln('device: ${snap.info.device}');
    buf.writeln('manufacturer: ${snap.info.manufacturer}');
    buf.writeln('product: ${snap.info.product}');
    buf.writeln('eposInAppReady: ${snap.info.eposInAppReady}');
    buf.writeln();
    buf.writeln('=== Flutter build ===');
    if (kReleaseMode) {
      buf.writeln('mode: release');
    } else if (kProfileMode) {
      buf.writeln('mode: profile');
    } else {
      buf.writeln('mode: debug');
    }
    buf.writeln('kDebugMode: $kDebugMode');
    buf.writeln();
    buf.writeln(
      '=== PosNativeDebugLog (recent UniPOS / EPOS channel traffic) ===',
    );
    buf.writeln(PosNativeDebugLog.formattedSession);
    return buf.toString();
  }
}
