import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ring buffer of recent native-bridge + optional HTTP lines for support / debugging
/// without switching to the bank EPOS or UniPOS app.
///
/// Ring buffer is always kept (bounded) so you can copy from the kiosk EPOS dialog
/// on release devices.
class PosNativeDebugLog {
  PosNativeDebugLog._();

  static const int _maxEntries = 48;
  static const int _maxCharsPerEntry = 12000;
  static final List<String> _lines = [];

  /// Appends a timestamped entry (trimmed). Also [debugPrint]s in debug mode.
  static void record(String source, String title, Object? payload) {
    final ts = DateTime.now().toIso8601String();
    String body;
    try {
      if (payload == null) {
        body = '(null)';
      } else if (payload is String) {
        body = payload;
      } else if (payload is Map) {
        body = const JsonEncoder.withIndent('  ').convert(payload);
      } else {
        body = payload.toString();
      }
    } catch (e) {
      body = '$payload (encode error: $e)';
    }
    if (body.length > _maxCharsPerEntry) {
      body = '${body.substring(0, _maxCharsPerEntry)}\n… (${body.length} chars total, truncated)';
    }
    final line = '[$ts] $source · $title\n$body';
    if (kDebugMode) {
      debugPrint('══ PosNativeDebugLog ══\n$line\n');
    }
    _lines.add(line);
    while (_lines.length > _maxEntries) {
      _lines.removeAt(0);
    }
  }

  static String get formattedSession {
    if (_lines.isEmpty) return '(no entries yet — run EPOS sync, UniPOS pay, or enable POS_DEBUG_PANEL)';
    return _lines.join('\n\n${'─' * 40}\n\n');
  }

  static Future<void> copySessionToClipboard() async {
    await Clipboard.setData(ClipboardData(text: formattedSession));
  }

  static Future<void> showSessionDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Native / terminal debug log'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                formattedSession,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.35,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await copySessionToClipboard();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copy all'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
