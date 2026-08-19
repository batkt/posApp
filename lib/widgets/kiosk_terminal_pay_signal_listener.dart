import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_model.dart';
import '../services/background_watchdog_service.dart';
import '../services/socket_service.dart';
import '../services/terminal_tulbur_signal_service.dart';
import '../services/unipos_service.dart';
import '../utils/mnt_amount_formatter.dart';

/// Listens for mobile-initiated card payment requests (`terminalTulburKhuseelt`)
/// and automatically opens UniPOS card payment terminal on this POS device.
class KioskTerminalPaySignalListener extends StatefulWidget {
  const KioskTerminalPaySignalListener({super.key, required this.child});

  final Widget child;

  @override
  State<KioskTerminalPaySignalListener> createState() =>
      _KioskTerminalPaySignalListenerState();
}

class _KioskTerminalPaySignalListenerState
    extends State<KioskTerminalPaySignalListener>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription? _socketSub;
  final TerminalTulburSignalService _svc = TerminalTulburSignalService();
  final Set<String> _handledIds = {};
  bool _pollInFlight = false;
  bool _isProcessingCardRequest = false;

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
      debugPrint('>>> [KioskTerminalPaySignalListener] App RESUMED — checking pending card requests');
      _poll();
    }
  }

  void _listenSocket() {
    _socketSub?.cancel();
    _socketSub = SocketService.instance.terminalTulburKhuseeltStream.listen((data) {
      final item = TerminalPaySignalItem.tryParse(data);
      if (item != null && !_handledIds.contains(item.id) && !_isProcessingCardRequest) {
        debugPrint('>>> [KioskTerminalPaySignalListener] Socket.IO card request received: ${item.id}');
        _processPayRequest(item);
      }
    });
  }

  void _armTimer() {
    _timer?.cancel();
    if (!mounted) return;
    final auth = context.read<AuthModel>();
    if (auth.posSession == null) return;
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
    if (!mounted || _pollInFlight || _isProcessingCardRequest) return;
    _pollInFlight = true;
    final auth = context.read<AuthModel>();
    final session = auth.posSession;
    if (session == null) {
      _pollInFlight = false;
      return;
    }

    List<TerminalPaySignalItem> list;
    try {
      list = await _svc.fetchPending(
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: session.salbariinId,
      );
    } catch (_) {
      _pollInFlight = false;
      return;
    }

    if (!mounted || list.isEmpty) {
      _pollInFlight = false;
      return;
    }

    for (final item in list) {
      if (!_handledIds.contains(item.id) && !_isProcessingCardRequest) {
        await _processPayRequest(item);
        break;
      }
    }
    _pollInFlight = false;
  }

  Future<void> _processPayRequest(TerminalPaySignalItem item) async {
    if (_handledIds.contains(item.id) || _isProcessingCardRequest) {
      debugPrint('>>> [KioskTerminalPaySignalListener] Skipping duplicate/concurrent card pay request: ${item.id}');
      return;
    }
    _isProcessingCardRequest = true;
    _handledIds.add(item.id); // Permanently remember to prevent infinite loops on resume!
    debugPrint('>>> [KioskTerminalPaySignalListener] EXECUTING CARD PAY REQUEST: ${item.id} (${item.amountMnt}₮) from ${item.initiatorNer}');

    final messenger = ScaffoldMessenger.of(context);

    // Protect active UniPOS transaction from watchdog disruption for 2 minutes
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        terminalWatchdogHeartbeatKey,
        DateTime.now().add(const Duration(minutes: 2)).toIso8601String(),
      );
    } catch (_) {}
    try {
      // If app is currently backgrounded/minimized, bring MainActivity to foreground first
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        debugPrint('>>> [KioskTerminalPaySignalListener] App backgrounded — bringing MainActivity to foreground before UniPOS launch');
        try {
          await const AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.LAUNCHER',
            package: 'mn.posease.mobile.terminal.pos',
            componentName: 'mn.posease.mobile.terminal.pos.MainActivity',
            flags: <int>[
              Flag.FLAG_ACTIVITY_NEW_TASK,
              Flag.FLAG_ACTIVITY_CLEAR_TOP,
              Flag.FLAG_ACTIVITY_SINGLE_TOP,
            ],
          ).launch();
          await Future.delayed(const Duration(milliseconds: 600));
        } catch (e) {
          debugPrint('Failed to bring MainActivity to foreground: $e');
        }
      }

      if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        try {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Картын төлбөрийн хүсэлт (${MntAmountFormatter.formatTugrik(item.amountMnt)}) — ПОС нээж байна...',
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue.shade800,
            ),
          );
        } catch (_) {}
      }

      // Auto-launch UniPOS payment terminal
      final res = await UniPosService.purchase(amount: item.amountMnt);
      UniPosService.requireSuccessfulTerminalCardPayment(res);

      await _svc.markCompleted(item.id);
      debugPrint('>>> [KioskTerminalPaySignalListener] Card payment successfully completed for ${item.id}');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${MntAmountFormatter.formatTugrik(item.amountMnt)} — UniPOS гүйлгээ амжилттай дууслаа!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on Exception catch (e) {
      debugPrint('>>> [KioskTerminalPaySignalListener] UniPOS transaction cancelled/failed: $e');
      // Cancel on backend so it is marked cancelled instead of staying pending
      try {
        await _svc.cancelRequest(item.id);
      } catch (_) {}

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Картын гүйлгээ цуцлагдлаа/алдаа гарлаа'),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isProcessingCardRequest = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
