import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../services/background_watchdog_service.dart';
import '../../widgets/chat_fab.dart';
import '../../widgets/kiosk_drawer.dart';
import '../../widgets/parked_guilgee_sheet.dart';
import '../../widgets/kiosk_terminal_pay_signal_listener.dart';
import '../../widgets/kiosk_terminal_barimt_signal_listener.dart';
import '../main/khaalt_screen.dart';
import 'pos_screen.dart';

/// Kiosk POS (`/khyanalt/kiosk`): same [POSScreen] as full app, plus drawer; electronic pay is **карт** (UniPOS CARD, not QPay).
class CashierMainScreen extends StatefulWidget {
  const CashierMainScreen({super.key});

  @override
  State<CashierMainScreen> createState() => _CashierMainScreenState();
}

class _CashierMainScreenState extends State<CashierMainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Only kiosk/terminal devices reach this screen (see PostLoginHome) — never
    // started for a plain mobile-cashier install.
    unawaited(_startBackgroundWatchdog());
  }

  Future<void> _startBackgroundWatchdog() async {
    debugPrint('>>> [CashierMainScreen] starting background watchdog…');
    try {
      final notifStatus = await Permission.notification.request(); // no-op pre-Android-13
      debugPrint('>>> [CashierMainScreen] notification permission: $notifStatus');
      await BackgroundWatchdogService.instance.ensureStarted();
      debugPrint('>>> [CashierMainScreen] background watchdog ensureStarted() done');
    } catch (e, st) {
      // Best-effort — terminal still prints normally while the app is open.
      debugPrint('>>> [CashierMainScreen] background watchdog failed to start: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthModel>();
    final user = auth.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const KioskDrawer(mobileStaffShell: false),
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Icon(Icons.payments_rounded, color: colorScheme.primary, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.tr('menu_kiosk_staff_shell'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    user?.name ?? '',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (auth.canSubmitPosSales && auth.posSession != null)
            IconButton(
              tooltip: l10n.tr('pos_park_queue'),
              onPressed: () =>
                  showParkedGuilgeeSheet(context, cashierMode: true),
              icon: const Icon(Icons.inventory_2_outlined),
            ),
          if (auth.canSubmitPosSales)
            IconButton(
              tooltip: l10n.tr('menu_khaalt'),
              icon: const Icon(Icons.payments_outlined),
              onPressed: () => showKhaaltModal(context),
            ),
        ],
      ),
      body: const Stack(
        children: [
          SafeArea(
            child: KioskTerminalPaySignalListener(
              child: KioskTerminalBarimtSignalListener(
                child: POSScreen(cashierMode: true),
              ),
            ),
          ),
          // Draggable floating chatbot button — same as MainScreen; this
          // screen (kiosk/cashier shell) never routes through MainScreen, so
          // without this the draggable chat button never appears here.
          ChatFab(),
        ],
      ),
    );
  }
}
