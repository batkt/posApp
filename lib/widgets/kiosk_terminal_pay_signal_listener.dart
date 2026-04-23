import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/locale_model.dart';
import '../services/pos_transaction_service.dart';
import '../services/terminal_tulbur_signal_service.dart';
import '../services/unipos_service.dart';
import '../utils/mnt_amount_formatter.dart';

/// While the kiosk POS screen is open, polls for mobile-initiated card requests
/// and offers to open UniPOS on this device.
class KioskTerminalPaySignalListener extends StatefulWidget {
  const KioskTerminalPaySignalListener({super.key, required this.child});

  final Widget child;

  @override
  State<KioskTerminalPaySignalListener> createState() =>
      _KioskTerminalPaySignalListenerState();
}

class _KioskTerminalPaySignalListenerState
    extends State<KioskTerminalPaySignalListener> {
  static const _pollInterval = Duration(seconds: 4);
  static const _snooze = Duration(minutes: 2);

  Timer? _timer;
  final TerminalTulburSignalService _svc = TerminalTulburSignalService();
  final Set<String> _sessionHandledIds = {};
  final Map<String, DateTime> _snoozeUntil = {};
  bool _dialogOpen = false;
  bool _pollInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _armTimer());
  }

  void _armTimer() {
    _timer?.cancel();
    if (!mounted) return;
    final auth = context.read<AuthModel>();
    if (!auth.canSubmitPosSales ||
        !auth.staffAccess.canPollTerminalPaySignals) {
      return;
    }
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
    _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _canOffer(String id) {
    if (_sessionHandledIds.contains(id)) return false;
    final until = _snoozeUntil[id];
    if (until != null && DateTime.now().isBefore(until)) return false;
    _snoozeUntil.remove(id);
    return true;
  }

  Future<void> _poll() async {
    if (!mounted || _dialogOpen || _pollInFlight) return;
    _pollInFlight = true;
    final auth = context.read<AuthModel>();
    if (!auth.canSubmitPosSales ||
        !auth.staffAccess.canPollTerminalPaySignals) {
      _pollInFlight = false;
      return;
    }
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
    if (!mounted || _dialogOpen || list.isEmpty) {
      _pollInFlight = false;
      return;
    }

    TerminalPaySignalItem? pick;
    for (final item in list) {
      if (_canOffer(item.id)) {
        pick = item;
        break;
      }
    }
    if (pick == null || !mounted) {
      _pollInFlight = false;
      return;
    }

    final item = pick;
    final messenger = ScaffoldMessenger.of(context);
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TerminalSignalDialog(
        item: item,
        onOpenUniPos: () async {
          try {
            final r = await UniPosService.purchase(amount: item.amountMnt);
            UniPosService.requireSuccessfulTerminalCardPayment(r);
          } on PosTransactionException catch (e) {
            if (!ctx.mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(e.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          if (!ctx.mounted) return;
          try {
            await _svc.markCompleted(item.id);
            if (!ctx.mounted) return;
            _sessionHandledIds.add(item.id);
            Navigator.of(ctx).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  '${MntAmountFormatter.formatTugrik(item.amountMnt)} — UniPOS дууссан',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } on TerminalTulburSignalException catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
        onLater: () {
          _snoozeUntil[item.id] = DateTime.now().add(_snooze);
          Navigator.of(ctx).pop();
        },
        onCancelServer: () async {
          try {
            await _svc.cancelRequest(item.id);
            if (!ctx.mounted) return;
            _sessionHandledIds.add(item.id);
            Navigator.of(ctx).pop();
          } on TerminalTulburSignalException catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
      ),
    );
    if (mounted) _dialogOpen = false;
    _pollInFlight = false;
    if (mounted) {
      unawaited(_poll());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TerminalSignalDialog extends StatelessWidget {
  const _TerminalSignalDialog({
    required this.item,
    required this.onOpenUniPos,
    required this.onLater,
    required this.onCancelServer,
  });

  final TerminalPaySignalItem item;
  final Future<void> Function() onOpenUniPos;
  final VoidCallback onLater;
  final Future<void> Function() onCancelServer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.tr('terminal_signal_kiosk_dialog_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.tr('terminal_signal_from_staff'),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.initiatorNer.isEmpty ? '—' : item.initiatorNer,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.tr('terminal_signal_amount'),
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          Text(
            MntAmountFormatter.formatTugrik(item.amountMnt),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (item.tailbar.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.tailbar,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onLater,
          child: Text(l10n.tr('terminal_signal_later')),
        ),
        TextButton(
          onPressed: () => onCancelServer(),
          child: Text(
            l10n.tr('terminal_signal_cancel_req'),
            style: TextStyle(color: cs.error),
          ),
        ),
        FilledButton(
          onPressed: () => onOpenUniPos(),
          child: Text(l10n.tr('terminal_signal_open_unipos')),
        ),
      ],
    );
  }
}
