import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../widgets/kiosk_drawer.dart';
import '../main/khaalt_screen.dart';
import '../pos/pos_screen.dart';

/// Staff with only `/khyanalt/mobile` in `tsonkhniiTokhirgoo`: same sale flow as kiosk
/// but no side drawer, two-step layout, and Бэлэн / **Карт** (UniPOS) / Данс.
class MobilePosMainScreen extends StatefulWidget {
  const MobilePosMainScreen({super.key});

  @override
  State<MobilePosMainScreen> createState() => _MobilePosMainScreenState();
}

class _MobilePosMainScreenState extends State<MobilePosMainScreen> {
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
      drawer: const KioskDrawer(mobileStaffShell: true),
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
            Icon(Icons.smartphone_rounded, color: colorScheme.primary, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.tr('pos'),
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
          if (auth.canSubmitPosSales)
            IconButton(
              tooltip: l10n.tr('menu_khaalt'),
              icon: const Icon(Icons.payments_outlined),
              onPressed: () => showKhaaltModal(context),
            ),
        ],
      ),
      body: const SafeArea(
        child: POSScreen(
          cashierMode: true,
          mobileStaffMode: true,
        ),
      ),
    );
  }
}
