import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/drawer_branch_switch.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'baraa_catalog_screen.dart';
import 'toololt_screen.dart';
import 'customers_screen.dart';
import 'sales_history_screen.dart';
import 'income_overview_screen.dart';
import 'purchase_list_screen.dart';
import 'login_screen.dart';
import 'out_of_stock_baraa_screen.dart';
import 'ebarimt_menu_screen.dart';
import 'staff_permissions_screen.dart';
import 'pos_settings_hub_screen.dart';
import 'tailan_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialSection});

  /// Optional drawer section id: `dashboard`, `staff_permissions`, `pos_settings`,
  /// `baraa_catalog`, `inventory`, `out_of_stock`, `toololt`, `ebarimt`, `customers`,
  /// `income_overview`, `purchase_list`, `tailan`, `history`.
  final String? initialSection;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _NavEntry {
  _NavEntry({required this.screen, required this.menu});

  final Widget screen;
  final _MenuItem menu;
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _appliedInitialSection = false;

  List<_NavEntry> _entriesFor(AuthModel auth) {
    final access = auth.staffAccess;
    final list = <_NavEntry>[];
    void push(Widget screen, _MenuItem menu) {
      final idx = list.length;
      list.add(_NavEntry(
        screen: screen,
        menu: _MenuItem(
          icon: menu.icon,
          selectedIcon: menu.selectedIcon,
          label: menu.label,
          section: menu.section,
          index: idx,
        ),
      ));
    }

    if (access.allowsDashboard) {
      push(
        const DashboardScreen(),
        _MenuItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'dashboard',
          section: 'dashboard',
          index: 0,
        ),
      );
    }
    if (access.allowsTailan) {
      push(
        const TailanScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.insert_chart_outlined,
          selectedIcon: Icons.insert_chart_rounded,
          label: 'tailan_menu',
          section: 'tailan',
          index: 0,
        ),
      );
    }
    if (access.hasFullAccess) {
      push(
        const StaffPermissionsScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.badge_outlined,
          selectedIcon: Icons.badge_rounded,
          label: 'menu_staff',
          section: 'staff_permissions',
          index: 0,
        ),
      );
    }
    if (auth.posSession != null) {
      push(
        const PosSettingsHubScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.tune_rounded,
          selectedIcon: Icons.tune_rounded,
          label: 'menu_pos_settings',
          section: 'pos_settings',
          index: 0,
        ),
      );
    }
    if (access.allowsBaraaMatrial) {
      push(
        const BaraaCatalogScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.list_alt_rounded,
          selectedIcon: Icons.list_alt_rounded,
          label: 'menu_baraa_list',
          section: 'baraa_catalog',
          index: 0,
        ),
      );
      push(
        const OutOfStockBaraaScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.remove_shopping_cart_outlined,
          selectedIcon: Icons.remove_shopping_cart,
          label: 'menu_out_of_stock_baraa',
          section: 'out_of_stock',
          index: 0,
        ),
      );
    }
    if (access.allowsBaraaOrlogokh) {
      push(
        const InventoryScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'inventory',
          section: 'inventory',
          index: 0,
        ),
      );
    }
    if (access.allowsToollogo) {
      push(
        const ToololtScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.calculate_outlined,
          selectedIcon: Icons.calculate_rounded,
          label: 'menu_toololt',
          section: 'toololt',
          index: 0,
        ),
      );
    }
    if (access.allowsEbarimt) {
      push(
        const EbarimtMenuScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'ebarimt',
          section: 'ebarimt',
          index: 0,
        ),
      );
    }
    if (access.allowsKhariltsagch) {
      push(
        const CustomersScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'customers',
          section: 'customers',
          index: 0,
        ),
      );
    }
    if (access.allowsHynalt) {
      push(
        const IncomeOverviewScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.trending_up_outlined,
          selectedIcon: Icons.trending_up_rounded,
          label: 'menu_orlogo',
          section: 'income_overview',
          index: 0,
        ),
      );
    }
    if (access.allowsBarimtiinJagsaalt) {
      push(
        const PurchaseListScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.shopping_cart_outlined,
          selectedIcon: Icons.shopping_cart_rounded,
          label: 'menu_hudaldan_avalt',
          section: 'purchase_list',
          index: 0,
        ),
      );
      push(
        const SalesHistoryScreen(showAppBar: false),
        _MenuItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'history',
          section: 'history',
          index: 0,
        ),
      );
    }
    return list;
  }

  void _onItemSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialSection());
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      _appliedInitialSection = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialSection());
    }
  }

  void _applyInitialSection() {
    if (!mounted || _appliedInitialSection || widget.initialSection == null) {
      return;
    }
    final auth = context.read<AuthModel>();
    final entries = _entriesFor(auth);
    final i = entries.indexWhere((e) => e.menu.section == widget.initialSection);
    if (i >= 0) {
      setState(() => _currentIndex = i);
    }
    _appliedInitialSection = true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthModel>();
    final user = auth.currentUser;
    final entries = _entriesFor(auth);
    final safeIndex =
        entries.isEmpty ? 0 : _currentIndex.clamp(0, entries.length - 1);
    if (safeIndex != _currentIndex && entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = safeIndex);
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          entries.isEmpty
              ? ''
              : l10n.tr(entries[safeIndex].menu.label),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: colorScheme.surface,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header with Logo - Enhanced
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Fast Logo - No Animation
                  ClipRRect(
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
                ],
              ),
            ),

            // User Profile Card - Enhanced
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
                  // Animated Avatar
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
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
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user?.name != null && user!.name.isNotEmpty
                          ? user.name
                          : 'Admin User',
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

            // Menu Items - Enhanced
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final item = entries[index].menu;
                  final isSelected = safeIndex == item.index;

                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 400 + (index * 50)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(-50 * (1 - value), 0),
                        child: Opacity(
                          opacity: value,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primaryContainer
                                      .withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: isSelected
                                  ? Border.all(
                                      color: colorScheme.primaryContainer,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                Navigator.pop(context); // close drawer
                                _onItemSelected(item.index);
                              },
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
                                  child: Row(
                                    children: [
                                      // Icon Container
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? colorScheme.primary
                                                  .withOpacity(0.2)
                                              : colorScheme
                                                  .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? item.selectedIcon
                                              : item.icon,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurfaceVariant,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Menu Text
                                      Expanded(
                                        child: Text(
                                          l10n.tr(item.label),
                                          style: textTheme.bodyLarge?.copyWith(
                                            color: isSelected
                                                ? colorScheme.primary
                                                : colorScheme.onSurface,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      // Selection Indicator
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: isSelected ? 4 : 0,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Logout Button - Enhanced
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
                    if (!mounted) return;
                    nav.pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen(),
                      ),
                      (_) => false,
                    );
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
      body: IndexedStack(
        index: entries.isEmpty ? 0 : safeIndex,
        children:
            entries.isEmpty ? [const SizedBox.shrink()] : entries.map((e) => e.screen).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
  final String section;

  _MenuItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    required this.section,
  });
}
