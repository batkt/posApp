import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../widgets/kiosk_drawer.dart';
import '../../widgets/kiosk_terminal_pay_signal_listener.dart';
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
      ),
      body: const SafeArea(
        child: KioskTerminalPaySignalListener(
          child: POSScreen(cashierMode: true),
        ),
      ),
    );
  }
}
