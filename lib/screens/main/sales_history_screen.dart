import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/payment_display_config.dart';
import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../models/sales_model.dart';
import '../../services/guilgee_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import '../../widgets/authenticated_image.dart';

String _fmtMnt(double v) => MntAmountFormatter.formatTugrik(v);

/// Best-effort label from `guilgeeniiTuukh.ajiltan` (id/ner only on older rows).
String? _saleStaffCaption(Map<String, dynamic>? a) {
  if (a == null || a.isEmpty) return null;
  final ner = a['ner'] ?? a['name'];
  if (ner != null && ner.toString().trim().isNotEmpty) {
    return ner.toString().trim();
  }
  final login = a['burtgeliinDugaar'];
  if (login != null && login.toString().trim().isNotEmpty) {
    return login.toString().trim();
  }
  final id = a['id'] ?? a['_id'];
  if (id != null && id.toString().trim().isNotEmpty) {
    return id.toString().trim();
  }
  return null;
}

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  Future<GuilgeeListResult>? _remoteFuture;
  String? _lastSessionKey;
  int _refreshGen = 0;

  static String? _resolveAjiltanId(AuthModel auth) {
    final u = auth.currentUser?.id.trim();
    if (u != null && u.isNotEmpty) return u;
    final pos = auth.posSession;
    if (pos == null) return null;
    final m = pos.ajiltan;
    final fromMap = m['_id']?.toString().trim() ?? m['id']?.toString().trim();
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    return null;
  }

  List<CompletedSale> _mergeRemoteAndLocal(
    List<CompletedSale> remote,
    List<CompletedSale> local,
  ) {
    final ids = remote.map((e) => e.id).toSet();
    final extra = local.where((s) => !ids.contains(s.id)).toList();
    return [...remote, ...extra];
  }

  Future<void> _onRefresh(
    AuthModel auth,
    bool allowRemote,
  ) async {
    if (!allowRemote || auth.posSession == null) return;
    setState(() => _refreshGen++);
    await Future<void>.delayed(Duration.zero);
    if (mounted && _remoteFuture != null) {
      try {
        await _remoteFuture;
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthModel>();
    final sales = context.watch<SalesModel>();

    final allow = auth.staffAccess.allowsSalesHistory;
    final pos = auth.posSession;
    final ajiltanId = _resolveAjiltanId(auth);
    final sessionKey = (allow && pos != null)
        ? '${pos.baiguullagiinId}|${pos.salbariinId}|$ajiltanId|$_refreshGen'
        : null;

    if (sessionKey != _lastSessionKey) {
      _lastSessionKey = sessionKey;
      _remoteFuture = (allow && pos != null)
          ? guilgeeService.listGuilgeeniiTuukh(
              baiguullagiinId: pos.baiguullagiinId,
              salbariinId: pos.salbariinId,
              ajiltanId: ajiltanId,
            )
          : null;
    }

    final canRemote = allow && pos != null && _remoteFuture != null;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.tr('sales_history'),
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              l10n.tr('sales_history_subtitle'),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (canRemote)
            IconButton(
              tooltip: l10n.tr('sales_history_refresh'),
              onPressed: () => _onRefresh(auth, true),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: _buildBody(
        context,
        colorScheme,
        textTheme,
        l10n,
        auth,
        sales,
        canRemote,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AppLocalizations l10n,
    AuthModel auth,
    SalesModel sales,
    bool canRemote,
  ) {
    if (!auth.staffAccess.allowsSalesHistory) {
      return _salesScrollable(
        context,
        sales.salesHistory,
        colorScheme,
        textTheme,
        l10n,
        canRemote: false,
        onRefresh: null,
      );
    }
    if (auth.posSession == null || _remoteFuture == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Material(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: colorScheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.tr('sales_history_offline_hint'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _salesScrollable(
              context,
              sales.salesHistory,
              colorScheme,
              textTheme,
              l10n,
              canRemote: false,
              onRefresh: null,
            ),
          ),
        ],
      );
    }

    return FutureBuilder<GuilgeeListResult>(
      future: _remoteFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  l10n.tr('sales_history_loading'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        final result = snapshot.data;
        if (result != null && result.success) {
          final merged = _mergeRemoteAndLocal(result.sales, sales.salesHistory);
          return _salesScrollable(
            context,
            merged,
            colorScheme,
            textTheme,
            l10n,
            canRemote: canRemote,
            onRefresh: canRemote ? () => _onRefresh(auth, true) : null,
          );
        }
        if (result != null && !result.success) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Material(
                  color: colorScheme.errorContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: colorScheme.error, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            result.error ?? l10n.tr('sales_history_load_error'),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onErrorContainer,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _salesScrollable(
                  context,
                  sales.salesHistory,
                  colorScheme,
                  textTheme,
                  l10n,
                  canRemote: canRemote,
                  onRefresh: canRemote ? () => _onRefresh(auth, true) : null,
                ),
              ),
            ],
          );
        }
        return _salesScrollable(
          context,
          sales.salesHistory,
          colorScheme,
          textTheme,
          l10n,
          canRemote: canRemote,
          onRefresh: canRemote ? () => _onRefresh(auth, true) : null,
        );
      },
    );
  }

  Widget _salesScrollable(
    BuildContext context,
    List<CompletedSale> list,
    ColorScheme colorScheme,
    TextTheme textTheme,
    AppLocalizations l10n, {
    required bool canRemote,
    required Future<void> Function()? onRefresh,
  }) {
    if (list.isEmpty) {
      final empty = _emptyState(colorScheme, textTheme, l10n);
      if (onRefresh == null) return empty;
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(hasScrollBody: false, child: empty),
          ],
        ),
      );
    }

    final grouped = _groupSalesByDate(list);
    final slivers = <Widget>[];
    for (final g in grouped) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: _DateHeader(date: g.date, l10n: l10n),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SaleCard(sale: g.sales[i], l10n: l10n),
              ),
              childCount: g.sales.length,
            ),
          ),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));

    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: slivers,
    );

    if (onRefresh == null) return scroll;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: scroll,
    );
  }

  Widget _emptyState(
    ColorScheme colorScheme,
    TextTheme textTheme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 56,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.tr('no_sales_history'),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tr('complete_sale_to_see'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DateGroup> _groupSalesByDate(List<CompletedSale> sales) {
    final groups = <DateTime, List<CompletedSale>>{};

    for (final sale in sales) {
      final date = DateTime(
        sale.timestamp.year,
        sale.timestamp.month,
        sale.timestamp.day,
      );
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
  final AppLocalizations l10n;

  const _DateHeader({required this.date, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final String label;
    if (date == today) {
      label = l10n.tr('today_label');
    } else     if (date == yesterday) {
      label = l10n.tr('yesterday');
    } else {
      final lang = Localizations.localeOf(context).languageCode;
      label = lang == 'mn'
          ? MongolianDateFormatter.formatSalesHistorySectionDate(date)
          : DateFormat('EEEE, MMM d, y').format(date);
    }

    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.primary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _SaleCard extends StatelessWidget {
  final CompletedSale sale;
  final AppLocalizations l10n;

  const _SaleCard({required this.sale, required this.l10n});

  int get _pieceCount =>
      sale.items.fold<int>(0, (sum, item) => sum + item.quantity);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final paymentIcon = PaymentDisplayConfig.iconForMethod(sale.paymentMethod);
    final paymentLabel = PaymentDisplayConfig.labelMn(sale.paymentMethod);
    final linesLabel = l10n
        .tr('sales_history_lines_count')
        .replaceAll('{n}', '${sale.items.length}');
    final staffCaption = _saleStaffCaption(sale.ajiltan);

    return Material(
      color: colorScheme.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showSaleDetails(context, sale, l10n),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.point_of_sale_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.id,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.tr('sales_history_time')}: ${MongolianDateFormatter.formatTime(sale.timestamp)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (staffCaption != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.tr('sales_history_staff')}: $staffCaption',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmtMnt(sale.total),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            paymentIcon,
                            size: 15,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            paymentLabel,
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$linesLabel · $_pieceCount ${l10n.tr('items_count')}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showSaleDetails(context, sale, l10n),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.tr('view_details')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showSaleDetails(
    BuildContext context,
    CompletedSale sale,
    AppLocalizations l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.38,
        expand: false,
        builder: (context, scrollController) {
          final staffCap = _saleStaffCaption(sale.ajiltan);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.tr('sale_completed'),
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('sales_history_order_no'),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        sale.id,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        () {
                          final lang =
                              Localizations.localeOf(context).languageCode;
                          if (lang == 'mn') {
                            return '${MongolianDateFormatter.formatShortDate(sale.timestamp)} · ${MongolianDateFormatter.formatTime(sale.timestamp)}';
                          }
                          return '${DateFormat.yMMMd().format(sale.timestamp)} · ${DateFormat.Hm().format(sale.timestamp)}';
                        }(),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (staffCap != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.tr('sales_history_staff'),
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          staffCap,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Material(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tr('total'),
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fmtMnt(sale.total),
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onPrimaryContainer,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n
                                .tr('receipt_qty_summary')
                                .replaceAll(
                                  '{pieces}',
                                  '${sale.items.fold<int>(0, (s, i) => s + i.quantity)}',
                                )
                                .replaceAll(
                                  '{lines}',
                                  '${sale.items.length}',
                                ),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    itemCount: sale.items.length,
                    itemBuilder: (context, index) {
                      final item = sale.items[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AuthenticatedImage(
                            imageUrl: item.product.imageUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          item.product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${item.quantity} × ${_fmtMnt(item.unitPrice)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Text(
                          _fmtMnt(item.total),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    border: Border(
                      top: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPriceRow(
                          l10n.tr('subtotal'),
                          sale.subtotal,
                          textTheme,
                          colorScheme,
                        ),
                        if (sale.discount > 0.009) ...[
                          const SizedBox(height: 6),
                          _buildPriceRow(
                            l10n.tr('discount'),
                            sale.discount,
                            textTheme,
                            colorScheme,
                            emphasize: false,
                          ),
                        ],
                        if (sale.tax > 0.009) ...[
                          const SizedBox(height: 6),
                          _buildPriceRow(
                            l10n.tr('vat'),
                            sale.tax,
                            textTheme,
                            colorScheme,
                          ),
                        ],
                        if (sale.nhhat > 0.009) ...[
                          const SizedBox(height: 6),
                          _buildPriceRow(
                            l10n.tr('nhhat_label'),
                            sale.nhhat,
                            textTheme,
                            colorScheme,
                          ),
                        ],
                        const Divider(height: 20),
                        _buildPriceRow(
                          l10n.tr('total'),
                          sale.total,
                          textTheme,
                          colorScheme,
                          isTotal: true,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.tr('sales_history_close_detail')),
                        ),
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

  static Widget _buildPriceRow(
    String label,
    double amount,
    TextTheme textTheme,
    ColorScheme colorScheme, {
    bool isTotal = false,
    bool emphasize = true,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
              : textTheme.bodyMedium?.copyWith(
                  color: emphasize
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
        ),
        Text(
          _fmtMnt(amount),
          style: isTotal
              ? textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )
              : textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
        ),
      ],
    );
  }
}
