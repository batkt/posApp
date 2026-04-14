import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/locale_model.dart';
import '../screens/main/ebarimt_menu_screen.dart';
import '../screens/main/login_screen.dart';
import '../screens/main/out_of_stock_baraa_screen.dart';
import '../screens/main/sales_history_screen.dart';

/// Side menu for kiosk mode: items mirror web `tsonkhniiTokhirgoo` flags.
class KioskDrawer extends StatelessWidget {
  const KioskDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthModel>();
    final access = auth.staffAccess;
    final user = auth.currentUser;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.payments_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.tr('menu_kiosk_title'),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (user?.name != null && user!.name.isNotEmpty)
                          Text(
                            user.name,
                            style: textTheme.bodySmall?.copyWith(
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
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (access.allowsAguulakh)
                    ListTile(
                      leading: const Icon(Icons.remove_shopping_cart_outlined),
                      title: Text(l10n.tr('menu_out_of_stock_baraa')),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const OutOfStockBaraaScreen(),
                          ),
                        );
                      },
                    ),
                  if (access.allowsEbarimt)
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(l10n.tr('ebarimt')),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const EbarimtMenuScreen(),
                          ),
                        );
                      },
                    ),
                  if (access.allowsSalesHistory)
                    ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: Text(l10n.tr('sales_history')),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const SalesHistoryScreen(),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: colorScheme.error),
              title: Text(
                l10n.tr('logout'),
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.tr('logout')),
                    content: Text(l10n.tr('logout_confirm_message')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.tr('cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                        ),
                        child: Text(l10n.tr('logout')),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
