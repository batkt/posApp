import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import 'sales_history_screen.dart';

/// Entry point for users with `tsonkhniiTokhirgoo` E-Баримт access (web `/khyanalt/eBarimt`).
class EbarimtMenuScreen extends StatelessWidget {
  const EbarimtMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('ebarimt')),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tr('ebarimt_menu_hint'),
              style: textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (auth.staffAccess.allowsSalesHistory)
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SalesHistoryScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.history_rounded),
                label: Text(l10n.tr('menu_open_sales_history')),
              ),
          ],
        ),
      ),
    );
  }
}
