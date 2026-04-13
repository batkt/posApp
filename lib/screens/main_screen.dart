import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/staff_screen_access.dart';
import '../models/auth_model.dart';
import '../models/locale_model.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'pos_screen.dart';
import 'inventory_screen.dart';
import 'customers_screen.dart';
import 'sales_history_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialSection});

  /// Optional drawer section id: `dashboard`, `pos`, `inventory`, `customers`, `history`, `profile`.
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

  List<_NavEntry> _entriesFor(StaffScreenAccess access) {
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
    if (access.allowsPosSystem) {
      push(
        const POSScreen(),
        _MenuItem(
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          label: 'pos',
          section: 'pos',
          index: 0,
        ),
      );
    }
    if (access.allowsAguulakh) {
      push(
        const InventoryScreen(),
        _MenuItem(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2,
          label: 'inventory',
          section: 'inventory',
          index: 0,
        ),
      );
    }
    if (access.allowsKhariltsagch) {
      push(
        const CustomersScreen(),
        _MenuItem(
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'customers',
          section: 'customers',
          index: 0,
        ),
      );
    }
    if (access.allowsSalesHistory) {
      push(
        const SalesHistoryScreen(),
        _MenuItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'history',
          section: 'history',
          index: 0,
        ),
      );
    }
    push(
      const ProfileScreen(),
      _MenuItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'profile',
        section: 'profile',
        index: 0,
      ),
    );
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
    final entries = _entriesFor(auth.staffAccess);
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
    final entries = _entriesFor(auth.staffAccess);
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
                    Navigator.pop(context); // Close drawer
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.tr('logout')),
                        content: Text(l10n.tr('logout_confirm_message')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(l10n.tr('cancel')),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                            ),
                            child: Text(l10n.tr('logout')),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await auth.logout();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                        (_) => false,
                      );
                    }
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
