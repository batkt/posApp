import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory_model.dart';
import '../../models/locale_model.dart';
import '../../models/sales_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import 'low_stock_baraa_screen.dart';
import 'out_of_stock_baraa_screen.dart';

String _fmtMnt(double v) => MntAmountFormatter.formatTugrik(v);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Total recorded revenue (local history)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Consumer<SalesModel>(
                  builder: (context, sales, _) {
                    return Container(
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
                          Text(
                            _fmtMnt(sales.totalRecordedRevenue),
                            style: textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n
                                .tr('dashboard_sale_count')
                                .replaceAll(
                                  '{n}',
                                  '${sales.totalRecordedSaleCount}',
                                ),
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
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Today's Summary
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Өнөөдрийн гүйлгээ',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Consumer<SalesModel>(
                      builder: (context, sales, child) {
                        return Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Орлого',
                                value: _fmtMnt(sales.todayRevenue),
                                icon: Icons.attach_money,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Гүйлгээ',
                                value: sales.todayTransactions.toString(),
                                icon: Icons.receipt,
                                color: colorScheme.primary,
                              ),
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
                    Consumer<SalesModel>(
                      builder: (context, sales, child) {
                        final recentSales = sales.salesHistory.take(5).toList();

                        if (recentSales.isEmpty) {
                          return _InfoCard(
                            icon: Icons.receipt_outlined,
                            message: 'No sales recorded yet',
                            color: colorScheme.outline,
                          );
                        }

                        return Column(
                          children: recentSales.map((sale) {
                            final pieces = sale.items
                                .fold<int>(0, (sum, i) => sum + i.quantity);
                            return _SaleListTile(
                              saleId: sale.id,
                              amount: sale.total,
                              time: sale.timestamp,
                              pieceCount: pieces,
                              lineCount: sale.items.length,
                              l10n: l10n,
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
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

  const _SaleListTile({
    required this.saleId,
    required this.amount,
    required this.time,
    required this.pieceCount,
    required this.lineCount,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final qtyLine = l10n
        .tr('receipt_qty_summary')
        .replaceAll('{pieces}', '$pieceCount')
        .replaceAll('{lines}', '$lineCount');

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
