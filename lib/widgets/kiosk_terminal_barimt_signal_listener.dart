import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../services/socket_service.dart';
import '../services/terminal_barimt_signal_service.dart';
import 'visual_receipt_renderer.dart';

/// Wraps POS screen. Listens for remote receipt print requests over Socket.IO
/// and HTTP polling, prints them on POS thermal printer, and marks completed.
class KioskTerminalBarimtSignalListener extends StatefulWidget {
  const KioskTerminalBarimtSignalListener({super.key, required this.child});

  final Widget child;

  @override
  State<KioskTerminalBarimtSignalListener> createState() =>
      _KioskTerminalBarimtSignalListenerState();
}

class _KioskTerminalBarimtSignalListenerState
    extends State<KioskTerminalBarimtSignalListener> {
  static const _pollInterval = Duration(seconds: 5);

  Timer? _timer;
  StreamSubscription? _socketSub;
  final TerminalBarimtSignalService _svc = TerminalBarimtSignalService();
  final Set<String> _handledIds = {};
  bool _pollInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenSocket();
      _armTimer();
    });
  }

  void _listenSocket() {
    _socketSub?.cancel();
    _socketSub = SocketService.instance.terminalBarimtKhuseeltStream.listen((data) {
      final id = data['id']?.toString();
      if (id != null && !_handledIds.contains(id)) {
        final item = TerminalBarimtSignalItem.tryParse(data);
        if (item != null) {
          _processPrintRequest(item);
        }
      }
    });
  }

  void _armTimer() {
    _timer?.cancel();
    if (!mounted) return;
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
    _poll();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (!mounted || _pollInFlight) return;
    _pollInFlight = true;
    final auth = context.read<AuthModel>();
    final session = auth.posSession;
    if (session == null) {
      _pollInFlight = false;
      return;
    }

    try {
      final list = await _svc.fetchPending(
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: session.salbariinId,
      );
      if (list.isNotEmpty) {
        debugPrint('>>> [KioskTerminalBarimtSignalListener] Found ${list.length} pending print requests for branch ${session.salbariinId}');
      }
      for (final item in list) {
        if (!_handledIds.contains(item.id)) {
          await _processPrintRequest(item);
        }
      }
    } catch (e) {
      debugPrint('>>> [KioskTerminalBarimtSignalListener] Poll error: $e');
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _processPrintRequest(TerminalBarimtSignalItem item) async {
    if (_handledIds.contains(item.id)) return;
    _handledIds.add(item.id);
    debugPrint('>>> [KioskTerminalBarimtSignalListener] EXECUTING PRINT REQUEST: ${item.id} from ${item.initiatorNer}');

    try {
      // Show snackbar / notification on POS terminal
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Баримт хэвлэх хүсэлт ирлээ (${item.initiatorNer.isNotEmpty ? item.initiatorNer : "Ажилтан"})',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Execute 100% pixel-perfect visual E-Barimt receipt image print matching ReceiptScreen
      try {
        final res = await VisualReceiptRenderer.printReceiptData(
          context,
          item.barimtData,
          initiatorNer: item.initiatorNer,
        );
        debugPrint('>>> [KioskTerminalBarimtSignalListener] Visual thermal print result: ${res.message}');
      } catch (err) {
        debugPrint('>>> [KioskTerminalBarimtSignalListener] Visual thermal print error: $err');
      }

      // Mark request completed on backend after processing
      await _svc.markCompleted(item.id);
    } catch (e) {
      debugPrint('Error processing remote print request: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
