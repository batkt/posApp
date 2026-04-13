import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/payment_display_config.dart';
import '../models/auth_model.dart';
import '../models/sales_model.dart';
import '../services/guilgee_service.dart';
import '../theme/app_theme.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  Future<GuilgeeListResult>? _remoteFuture;
  String? _lastSessionKey;

  List<CompletedSale> _mergeRemoteAndLocal(
    List<CompletedSale> remote,
    List<CompletedSale> local,
  ) {
    final ids = remote.map((e) => e.id).toSet();
    final extra = local.where((s) => !ids.contains(s.id)).toList();
    return [...remote, ...extra];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthModel>();
    final sales = context.watch<SalesModel>();

    final allow = auth.staffAccess.allowsSalesHistory;
    final pos = auth.posSession;
    final sessionKey = (allow && pos != null)
        ? '${pos.baiguullagiinId}|${pos.salbariinId}'
        : null;

    if (sessionKey != _lastSessionKey) {
      _lastSessionKey = sessionKey;
      _remoteFuture = (allow && pos != null)
          ? guilgeeService.listGuilgeeniiTuukh(
              baiguullagiinId: pos.baiguullagiinId,
              salbariinId: pos.salbariinId,
            )
          : null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Борлуулалтын түүх'),
        centerTitle: true,
      ),
      body: _buildBody(context, colorScheme, textTheme, auth, sales),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AuthModel auth,
    SalesModel sales,
  ) {
    if (!auth.staffAccess.allowsSalesHistory) {
      return _salesListOrEmpty(sales.salesHistory, colorScheme, textTheme);
    }
    if (auth.posSession == null || _remoteFuture == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Салбарын мэдээлэл байхгүй. Зөвхөн энэ төхөөрөмжийн түүх харагдана.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: _salesListOrEmpty(sales.salesHistory, colorScheme, textTheme),
          ),
        ],
      );
    }

    return FutureBuilder<GuilgeeListResult>(
      future: _remoteFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final result = snapshot.data;
        if (result != null && result.success) {
          final merged =
              _mergeRemoteAndLocal(result.sales, sales.salesHistory);
          return _salesListOrEmpty(merged, colorScheme, textTheme);
        }
        if (result != null && !result.success) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  result.error ?? 'Ачаалахад алдаа',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
              Expanded(
                child:
                    _salesListOrEmpty(sales.salesHistory, colorScheme, textTheme),
              ),
            ],
          );
        }
        return _salesListOrEmpty(sales.salesHistory, colorScheme, textTheme);
      },
    );
  }

  Widget _salesListOrEmpty(
    List<CompletedSale> list,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Борлуулалт бүртгэгдээгүй',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Борлуулалт хийж энд харна уу',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final groupedSales = _groupSalesByDate(list);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedSales.length,
      itemBuilder: (context, index) {
        final dateGroup = groupedSales[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(date: dateGroup.date),
            const SizedBox(height: 8),
            ...dateGroup.sales.map((sale) => _SaleCard(sale: sale)),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  List<_DateGroup> _groupSalesByDate(List<CompletedSale> sales) {
    final groups = <DateTime, List<CompletedSale>>{};

    for (final sale in sales) {
      final date = DateTime(
          sale.timestamp.year, sale.timestamp.month, sale.timestamp.day);
      groups.putIfAbsent(date, () => []);
      groups[date]!.add(sale);
    }

    final sortedDates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return sortedDates
        .map((date) => _DateGroup(
              date: date,
              sales: groups[date]!
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
            ))
        .toList();
  }
}

class _DateGroup {
  final DateTime date;
  final List<CompletedSale> sales;

  _DateGroup({required this.date, required this.sales});
}

class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == today) {
      label = 'Today';
    } else if (date == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEEE, MMMM d').format(date);
    }

    return Text(
      label,
      style: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: colorScheme.primary,
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final CompletedSale sale;

  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    final paymentIcon = PaymentDisplayConfig.iconForMethod(sale.paymentMethod);
    final paymentLabel = PaymentDisplayConfig.labelEn(sale.paymentMethod);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showSaleDetails(context, sale),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.id,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          DateFormat('h:mm a').format(sale.timestamp),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(sale.total),
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(paymentIcon,
                              size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            paymentLabel,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${sale.items.fold(0, (sum, item) => sum + item.quantity)} items',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showSaleDetails(context, sale),
                    child: const Text('View Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaleDetails(BuildContext context, CompletedSale sale) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currencyFormat =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sale Completed',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sale.id,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Items List
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sale.items.length,
                    itemBuilder: (context, index) {
                      final item = sale.items[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.product.imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 48,
                                height: 48,
                                color: colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ),
                        title: Text(item.product.name),
                        subtitle: Text(
                            '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}'),
                        trailing: Text(
                          currencyFormat.format(item.total),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Summary
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        _buildPriceRow(
                            'Subtotal', sale.subtotal, textTheme, colorScheme),
                        const SizedBox(height: 8),
                        _buildPriceRow('Tax', sale.tax, textTheme, colorScheme),
                        const Divider(height: 24),
                        _buildPriceRow(
                            'Total', sale.total, textTheme, colorScheme,
                            isTotal: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount,
    TextTheme textTheme,
    ColorScheme colorScheme, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
              : textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: isTotal
              ? textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                )
              : textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
        ),
      ],
    );
  }
}
