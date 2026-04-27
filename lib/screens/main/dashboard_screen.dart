import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/inventory_model.dart';
import '../../models/locale_model.dart';
import '../../models/sales_model.dart';
import '../../services/guilgee_service.dart';
import '../../services/hynalt_tailan_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import 'low_stock_baraa_screen.dart';
import 'out_of_stock_baraa_screen.dart';

String _fmtMnt(double v) => MntAmountFormatter.formatTugrik(v);

String? _ajiltanNerFromSale(CompletedSale s) {
  final a = s.ajiltan;
  if (a == null) return null;
  final n = a['ner'] ?? a['name'];
  final t = n?.toString().trim() ?? '';
  if (t.isEmpty) return null;
  return t;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final HynaltTailanService _hynalt = HynaltTailanService();
  final GuilgeeService _guilgee = GuilgeeService();

  String? _sessionKey;
  bool _loading = true;
  String? _loadError;
  DashboardMedeelelResult? _monthDash;
  DashboardMedeelelResult? _todayDash;
  List<CompletedSale> _recentBranch = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.read<AuthModel>().posSession;
    final k = s == null ? null : '${s.baiguullagiinId}\t${s.salbariinId}';
    if (k == _sessionKey) return;
    _sessionKey = k;
    if (k == null) {
      if (_loading || _monthDash != null || _loadError != null) {
        setState(() {
          _loading = false;
          _monthDash = null;
          _todayDash = null;
          _recentBranch = const [];
          _loadError = null;
        });
      }
    } else {
      _load();
    }
  }

  DateTimeRange _currentMonthLocal() {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month, 1),
      end: DateTime(n.year, n.month + 1, 0, 23, 59, 59),
    );
  }

  DateTimeRange _todayLocal() {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month, n.day),
      end: DateTime(n.year, n.month, n.day, 23, 59, 59),
    );
  }

  Future<void> _load() async {
    final session = context.read<AuthModel>().posSession;
    if (session == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = null;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final month = _currentMonthLocal();
    final day = _todayLocal();
    final ba = session.baiguullagiinId;
    final sal = session.salbariinId;

    final m = await _hynalt.fetchDashboardMedeelel(
      baiguullagiinId: ba,
      salbariinId: sal,
      ekhlekh: month.start,
      duusakh: month.end,
    );
    final d = await _hynalt.fetchDashboardMedeelel(
      baiguullagiinId: ba,
      salbariinId: sal,
      ekhlekh: day.start,
      duusakh: day.end,
    );
    final list = await _guilgee.listGuilgeeniiTuukh(
      baiguullagiinId: ba,
      salbariinId: sal,
      page: 1,
      pageSize: 5,
    );

    if (!mounted) return;
    String? err;
    if (!m.ok) {
      err = m.error;
    } else if (!d.ok) {
      err = d.error;
    } else if (!list.success) {
      err = list.error;
    }
    setState(() {
      _loading = false;
      _monthDash = m;
      _todayDash = d;
      _loadError = err;
      _recentBranch = list.success ? list.sales : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final monthOk = _monthDash?.ok == true;
    final todayOk = _todayDash?.ok == true;
    final monthBorl = monthOk ? _monthDash!.borluulalt : 0.0;
    final monthN = monthOk ? _monthDash!.guilgeeShirheg : 0;
    final todayBorl = todayOk ? _todayDash!.borluulalt : 0.0;
    final todayN = todayOk ? _todayDash!.guilgeeShirheg : 0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withValues(alpha: 0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.savings_rounded,
                              color: colorScheme.onPrimary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.tr('dashboard_total_recorded'),
                                style: textTheme.titleSmall?.copyWith(
                                  color: colorScheme.onPrimary
                                      .withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_loading && _monthDash == null)
                          SizedBox(
                            height: 40,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        else
                          Text(
                            _loadError != null && !monthOk
                                ? '—'
                                : _fmtMnt(monthBorl),
                            style: textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          l10n
                              .tr('dashboard_sale_count')
                              .replaceAll('{n}', '$monthN'),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimary
                                .withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.tr('dashboard_total_recorded_hint'),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimary
                                .withValues(alpha: 0.75),
                          ),
                        ),
                        if (_loadError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _loadError!,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // Today's Summary (branch-wide from API)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('dashboard_today_title'),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loading && _todayDash == null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: l10n.tr('dashboard_today_income'),
                              value: !todayOk ? '—' : _fmtMnt(todayBorl),
                              icon: Icons.attach_money,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: l10n.tr('dashboard_today_tx'),
                              value: '$todayN',
                              icon: Icons.receipt,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Inventory Status
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Агуулахын байдал',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(l10n.tr('view_all')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Consumer<InventoryModel>(
                      builder: (context, inventory, child) {
                        final lowStock = inventory.lowStockItems;
                        final outOfStock = inventory.outOfStockItems;

                        if (lowStock.isEmpty && outOfStock.isEmpty) {
                          return _InfoCard(
                            icon: Icons.check_circle,
                            message: 'Агуулахын бүх хэмжээ хэвийн байна',
                            color: AppColors.success,
                          );
                        }

                        return Column(
                          children: [
                            if (outOfStock.isNotEmpty)
                              _AlertCard(
                                icon: Icons.error,
                                title:
                                    '${outOfStock.length} бүтээгдэхүүн дууссан',
                                color: AppColors.error,
                                onTap: () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const OutOfStockBaraaScreen(),
                                    ),
                                  );
                                },
                              ),
                            if (outOfStock.isNotEmpty && lowStock.isNotEmpty)
                              const SizedBox(height: 8),
                            if (lowStock.isNotEmpty)
                              _AlertCard(
                                icon: Icons.warning,
                                title:
                                    '${lowStock.length} бүтээгдэхүүн цөөн үлдсэн',
                                color: AppColors.warning,
                                onTap: () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const LowStockBaraaScreen(),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Recent Sales
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Сүүлийн борлуулалт',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(l10n.tr('view_all')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loading && _recentBranch.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_recentBranch.isEmpty)
                      _InfoCard(
                        icon: Icons.receipt_outlined,
                        message: l10n.tr('dashboard_no_recent'),
                        color: colorScheme.outline,
                      )
                    else
                      Column(
                        children: _recentBranch.map((sale) {
                          final pieces = sale.items
                              .fold<int>(0, (sum, i) => sum + i.quantity);
                          return _SaleListTile(
                            saleId: sale.id,
                            amount: sale.total,
                            time: sale.timestamp,
                            pieceCount: pieces,
                            lineCount: sale.items.length,
                            l10n: l10n,
                            cashierName: _ajiltanNerFromSale(sale),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: color.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleListTile extends StatelessWidget {
  final String saleId;
  final double amount;
  final DateTime time;
  final int pieceCount;
  final int lineCount;
  final AppLocalizations l10n;
  final String? cashierName;

  const _SaleListTile({
    required this.saleId,
    required this.amount,
    required this.time,
    required this.pieceCount,
    required this.lineCount,
    required this.l10n,
    this.cashierName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final qtyLine = l10n
        .tr('receipt_qty_summary')
        .replaceAll('{pieces}', '$pieceCount')
        .replaceAll('{lines}', '$lineCount');
    final cName = cashierName;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saleId,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (cName != null && cName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    cName,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                Text(
                  '$qtyLine · ${MongolianDateFormatter.formatTime(time)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _fmtMnt(amount),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
