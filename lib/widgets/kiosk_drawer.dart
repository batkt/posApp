import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/locale_model.dart';
import '../screens/main/ebarimt_menu_screen.dart';
import '../screens/main/baraa_catalog_screen.dart';
import '../screens/main/customers_screen.dart';
import '../screens/main/inventory_screen.dart';
import '../screens/main/out_of_stock_baraa_screen.dart';
import '../screens/main/sales_history_screen.dart';
import '../screens/main/income_overview_screen.dart';
import '../screens/main/purchase_list_screen.dart';
import '../screens/main/pos_settings_hub_screen.dart';
import '../screens/main/tailan_screen.dart';
import '../screens/main/toololt_screen.dart';
import '../theme/app_theme.dart';
import '../utils/pos_native_debug_log.dart';
import '../services/printer_service.dart';
import '../services/terminal_hardware_service.dart';
import '../utils/pos_shell_reset.dart';
import 'drawer_branch_switch.dart';

/// Side menu for kiosk / mobile POS — same visual design as [MainScreen] drawer.
class KioskDrawer extends StatelessWidget {
  const KioskDrawer({super.key, this.mobileStaffShell = false});

  /// True when used from [MobilePosMainScreen] (QPay); false for kiosk register.
  final bool mobileStaffShell;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthModel>();
    final access = auth.staffAccess;
    final user = auth.currentUser;

    final menuActions = <_KioskMenuAction>[
      if (access.allowsBaraaMatrial)
        _KioskMenuAction(
          icon: Icons.list_alt_rounded,
          labelKey: 'menu_baraa_list',
          onTap: (ctx) =>
              kioskDrawerLeavePosForPage(ctx, const BaraaCatalogScreen()),
        ),
      if (access.allowsToollogo)
        _KioskMenuAction(
          icon: Icons.calculate_outlined,
          labelKey: 'menu_toololt',
          onTap: (ctx) => kioskDrawerLeavePosForPage(ctx, const ToololtScreen()),
        ),
      if (access.allowsBaraaMatrial)
        _KioskMenuAction(
          icon: Icons.remove_shopping_cart_outlined,
          labelKey: 'menu_out_of_stock_baraa',
          onTap: (ctx) => kioskDrawerLeavePosForPage(
            ctx,
            const OutOfStockBaraaScreen(),
          ),
        ),
      if (access.allowsEbarimt)
        _KioskMenuAction(
          icon: Icons.receipt_long_outlined,
          labelKey: 'ebarimt',
          onTap: (ctx) =>
              kioskDrawerLeavePosForPage(ctx, const EbarimtMenuScreen()),
        ),
      if (access.allowsHynalt)
        _KioskMenuAction(
          icon: Icons.trending_up_rounded,
          labelKey: 'menu_orlogo',
          onTap: (ctx) => kioskDrawerLeavePosForPage(
            ctx,
            const IncomeOverviewScreen(),
          ),
        ),
      if (access.allowsTailan)
        _KioskMenuAction(
          icon: Icons.insert_chart_outlined,
          labelKey: 'tailan_menu',
          onTap: (ctx) => kioskDrawerLeavePosForPage(ctx, const TailanScreen()),
        ),
      if (access.allowsBarimtiinJagsaalt)
        _KioskMenuAction(
          icon: Icons.shopping_cart_outlined,
          labelKey: 'menu_hudaldan_avalt',
          onTap: (ctx) =>
              kioskDrawerLeavePosForPage(ctx, const PurchaseListScreen()),
        ),
      if (access.allowsBarimtiinJagsaalt)
        _KioskMenuAction(
          icon: Icons.history_rounded,
          labelKey: 'sales_history',
          onTap: (ctx) =>
              kioskDrawerLeavePosForPage(ctx, const SalesHistoryScreen()),
        ),
      if (access.allowsBaraaOrlogokh)
        _KioskMenuAction(
          icon: Icons.inventory_2_outlined,
          labelKey: 'inventory',
          onTap: (ctx) =>
              kioskDrawerLeavePosForPage(ctx, const InventoryScreen()),
        ),
      if (access.allowsKhariltsagch)
        _KioskMenuAction(
          icon: Icons.people_outline,
          labelKey: 'customers',
          onTap: (ctx) =>
              kioskDrawerLeavePosForPage(ctx, const CustomersScreen()),
        ),
      if (auth.posSession != null)
        _KioskMenuAction(
          icon: Icons.tune_rounded,
          labelKey: 'menu_pos_settings',
          onTap: (ctx) => kioskDrawerLeavePosForPage(
            ctx,
            const PosSettingsHubScreen(showAppBar: true),
          ),
        ),
      if (access.allowsEbarimt)
        _KioskMenuAction(
          icon: Icons.sync_problem_rounded,
          labelKey: 'epos_sync',
          onTap: (ctx) async {
            final l10n = AppLocalizations.of(ctx);
            // Close drawer
            Navigator.pop(ctx);

            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.tr('epos_sync_hint'))),
                  ],
                ),
              ),
            );

            final res = await PrinterService.performEposHealthCheck();

            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).hideCurrentSnackBar();

              String finalMessage = res.message;
              if (res.success && res.data != null) {
                final mid = res.data?['merchantId'] ?? res.data?['merchantName'];
                final tid = res.data?['terminalId'];
                if (mid != null || tid != null) {
                  finalMessage += '\nMID: $mid | TID: $tid';
                }
              }

              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(finalMessage),
                  backgroundColor:
                      res.success ? AppColors.success : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );

              final debugBody = PrinterService.formatEposHealthCheckDebugText(res);
              await showDialog<void>(
                context: ctx,
                builder: (dCtx) => AlertDialog(
                  title: Text(
                    res.success
                        ? 'EPOS холболт (дэлгэрэнгүй)'
                        : 'EPOS алдаа (дэлгэрэнгүй)',
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 360,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(dCtx).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: SelectableText(
                          debugBody,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.35,
                            color: Theme.of(dCtx).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        await PosNativeDebugLog.copySessionToClipboard();
                        if (dCtx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Session log copied to clipboard'),
                            ),
                          );
                        }
                      },
                      child: const Text('Copy session log'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dCtx);
                        PosNativeDebugLog.showSessionDialog(ctx);
                      },
                      child: const Text('View session log'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx),
                      child: const Text('Хаах'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      if (access.allowsEbarimt)
        _KioskMenuAction(
          icon: Icons.info_outline_rounded,
          labelKey: 'menu_terminal_routing_debug',
          onTap: (ctx) async {
            final l10n = AppLocalizations.of(ctx);
            Navigator.pop(ctx);
            final body = await TerminalHardwareInfo.buildRoutingDebugReport();
            if (!ctx.mounted) return;
            await showDialog<void>(
              context: ctx,
              builder: (dCtx) => AlertDialog(
                title: Text(l10n.tr('menu_terminal_routing_debug_title')),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 420,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(dCtx).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: SelectableText(
                        body,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.35,
                          color: Theme.of(dCtx).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: body));
                      if (dCtx.mounted) Navigator.pop(dCtx);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(l10n.tr('routing_debug_copied')),
                          ),
                        );
                      }
                    },
                    child: const Text('Copy'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dCtx);
                      PosNativeDebugLog.showSessionDialog(ctx);
                    },
                    child: const Text('Full session log'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: Text(l10n.tr('cancel')),
                  ),
                ],
              ),
            );
          },
        ),
      if (access.allowsEbarimt)
        _KioskMenuAction(
          icon: Icons.print_outlined,
          labelKey: 'pax_test_print',
          onTap: (ctx) async {
            final l10n = AppLocalizations.of(ctx);
            Navigator.pop(ctx);

            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.tr('pax_test_print_hint'))),
                  ],
                ),
              ),
            );

            final res = await PrinterService.testPrint();

            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).hideCurrentSnackBar();

              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(res.message),
                  backgroundColor:
                      res.success ? AppColors.success : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );

              final debugBody =
                  PrinterService.formatPaxTestPrintDebugText(res);
              await showDialog<void>(
                context: ctx,
                builder: (dCtx) => AlertDialog(
                  title: Text(
                    res.success
                        ? 'PAX тест (дэлгэрэнгүй)'
                        : 'PAX тест — алдаа (дэлгэрэнгүй)',
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 360,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(dCtx).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(10),
                        child: SelectableText(
                          debugBody,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.35,
                            color: Theme.of(dCtx).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx),
                      child: const Text('Хаах'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
    ];

    return Drawer(
      backgroundColor: colorScheme.surface,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/poslogo.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.contain,
                  cacheWidth: 144,
                  cacheHeight: 144,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.store,
                        color: colorScheme.onPrimary,
                        size: 36,
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer.withOpacity(0.4),
                    colorScheme.primaryContainer.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primaryContainer.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        user?.name != null && user!.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : 'A',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user?.name != null && user!.name.isNotEmpty
                              ? user.name
                              : l10n.tr('menu_kiosk_title'),
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.tr(
                            mobileStaffShell
                                ? 'menu_mobile_staff_shell'
                                : 'menu_kiosk_staff_shell',
                          ),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.verified,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
            const DrawerBranchSwitchSection(),
            const SizedBox(height: 8),
            Expanded(
              child: menuActions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.tr(
                            mobileStaffShell
                                ? 'menu_mobile_staff_shell'
                                : 'menu_kiosk_staff_shell',
                          ),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: menuActions.length,
                      itemBuilder: (context, index) {
                        final action = menuActions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => action.onTap(context),
                              borderRadius: BorderRadius.circular(14),
                              splashColor: colorScheme.primaryContainer
                                  .withOpacity(0.2),
                              highlightColor: colorScheme.primaryContainer
                                  .withOpacity(0.1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        action.icon,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        l10n.tr(action.labelKey),
                                        style: textTheme.bodyLarge?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.errorContainer.withOpacity(0.3),
                    colorScheme.errorContainer.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.errorContainer.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final nav = Navigator.of(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(l10n.tr('logout')),
                        content: Text(l10n.tr('logout_confirm_message')),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: Text(l10n.tr('cancel')),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                            ),
                            child: Text(l10n.tr('logout')),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    nav.pop();
                    await auth.logout();
                    // [AuthWrapper] shows login after session clear (see main_screen logout).
                  },
                  borderRadius: BorderRadius.circular(14),
                  splashColor: colorScheme.errorContainer.withOpacity(0.2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.error.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: colorScheme.error,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          l10n.tr('logout'),
                          style: textTheme.bodyLarge?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _KioskMenuAction {
  _KioskMenuAction({
    required this.icon,
    required this.labelKey,
    required this.onTap,
  });

  final IconData icon;
  final String labelKey;
  final void Function(BuildContext context) onTap;
}
