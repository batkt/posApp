import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_model.dart';
import '../services/background_watchdog_service.dart';
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
    extends State<KioskTerminalBarimtSignalListener>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription? _socketSub;
  final TerminalBarimtSignalService _svc = TerminalBarimtSignalService();
  final Set<String> _handledIds = {};
  bool _pollInFlight = false;
  bool _isProcessingPrintRequest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenSocket();
      _armTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('>>> [KioskTerminalBarimtSignalListener] App RESUMED — immediate poll for pending print requests');
      _poll();
    }
  }

  void _listenSocket() {
    _socketSub?.cancel();
    _socketSub = SocketService.instance.terminalBarimtKhuseeltStream.listen((data) {
      final id = data['id']?.toString();
      if (id != null && !_handledIds.contains(id) && !_isProcessingPrintRequest) {
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
    final pollInterval = SocketService.instance.isConnected
        ? const Duration(seconds: 8)
        : const Duration(seconds: 3);
    _timer = Timer.periodic(pollInterval, (_) => _poll());
    _poll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_pollInFlight || _isProcessingPrintRequest || !mounted) return;
    _pollInFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        terminalWatchdogHeartbeatKey,
        DateTime.now().toIso8601String(),
      );

      if (!mounted) return;
      final auth = context.read<AuthModel>();
      final session = auth.posSession;
      if (session == null) {
        _pollInFlight = false;
        return;
      }

      final items = await _svc.fetchPending(
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: session.salbariinId,
      );
      if (items.isNotEmpty) {
        debugPrint(
          '>>> [KioskTerminalBarimtSignalListener] Found ${items.length} pending print requests for branch ${session.salbariinId}',
        );
      }
      for (final item in items) {
        if (!_handledIds.contains(item.id) && !_isProcessingPrintRequest) {
          await _processPrintRequest(item);
          break;
        }
      }
    } catch (e) {
      debugPrint('>>> [KioskTerminalBarimtSignalListener] Poll error: $e');
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _processPrintRequest(TerminalBarimtSignalItem item) async {
    if (_handledIds.contains(item.id) || _isProcessingPrintRequest) return;
    _isProcessingPrintRequest = true;
    _handledIds.add(item.id);
    debugPrint('>>> [KioskTerminalBarimtSignalListener] EXECUTING PRINT REQUEST: ${item.id} from ${item.initiatorNer}');

    var success = false;
    try {
      // Show snackbar on POS terminal if foreground UI is active
      if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Баримт хэвлэх хүсэлт ирлээ (${item.initiatorNer.isNotEmpty ? item.initiatorNer : "Ажилтан"})',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (_) {}
      }

      // Execute 100% pixel-perfect visual PNG receipt image rendering via offscreen PipelineOwner
      try {
        final res = await VisualReceiptRenderer.printReceiptData(
          context,
          item.barimtData,
          initiatorNer: item.initiatorNer,
        );
        success = res.success;
        debugPrint('>>> [KioskTerminalBarimtSignalListener] Visual thermal print result: ${res.message}');
      } catch (err) {
        debugPrint('>>> [KioskTerminalBarimtSignalListener] Visual thermal print error: $err');
      }

      // Mark request completed on backend after processing (success or fail) to prevent infinite loop
      try {
        await _svc.markCompleted(item.id);
        debugPrint('>>> [KioskTerminalBarimtSignalListener] Marked completed: ${item.id} (success=$success)');
      } catch (e) {
        debugPrint('>>> [KioskTerminalBarimtSignalListener] Failed to mark completed on backend: $e');
      }
    } catch (e) {
      debugPrint('Error processing remote print request: $e');
    } finally {
      _isProcessingPrintRequest = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
