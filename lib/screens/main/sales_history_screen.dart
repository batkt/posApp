import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/payment_display_config.dart';
import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../models/sales_model.dart';
import '../../services/guilgee_service.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import '../../widgets/completed_sale_detail_sheet.dart';
import '../../widgets/parked_guilgee_sheet.dart';
import '../../widgets/sale_year_month_filter_bar.dart';

String _fmtMnt(double v) => MntAmountFormatter.formatTugrik(v);

/// Sale detail bottom sheet — same modal shell as [showKhaaltModal] (`completed_sale_detail_sheet.dart`).
void showPOSCompletedSaleSheet(
  BuildContext context,
  CompletedSale sale,
  AppLocalizations l10n,
) =>
    showCompletedSaleDetailSheet(context, sale);

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
  const SalesHistoryScreen({super.key, this.showAppBar = true});

  /// False when shown inside [MainScreen] (shell already shows [sales_history]).
  final bool showAppBar;

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  Future<GuilgeeListResult>? _remoteFuture;
  String? _lastSessionKey;
  int _refreshGen = 0;
  int? _filterYear;
  int? _filterMonth;

  void _onDateFilter(int? year, int? month) {
    setState(() {
      _filterYear = year;
      _filterMonth = year == null ? null : month;
    });
  }

  List<CompletedSale> _applyDateFilter(List<CompletedSale> list) {
    return list
        .where(
          (s) => saleMatchesYearMonthFilter(
            s.timestamp,
            _filterYear,
            _filterMonth,
          ),
        )
        .toList();
  }

  Widget _dateFilterBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SaleYearMonthFilterBar(
        l10n: l10n,
        selectedYear: _filterYear,
        selectedMonth: _filterMonth,
        onFilterChanged: _onDateFilter,
      ),
    );
  }

  Widget _bodyWithDateFilter(
    AppLocalizations l10n,
    Widget inner, {
    Widget? belowFilter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dateFilterBar(l10n),
        if (belowFilter != null) belowFilter,
        Expanded(child: inner),
      ],
    );
  }

  Widget? _parkedQueueBanner(
    BuildContext context,
    AuthModel auth,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (!auth.canSubmitPosSales || auth.posSession == null) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Material(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showParkedGuilgeeSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: colorScheme.primary,
                  size: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('pos_park_queue'),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.tr('pos_park_queue_banner_hint'),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
      appBar: widget.showAppBar
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.tr('sales_history'),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
                if (auth.canSubmitPosSales && auth.posSession != null)
                  IconButton(
                    tooltip: l10n.tr('pos_park_queue'),
                    onPressed: () => showParkedGuilgeeSheet(context),
                    icon: const Icon(Icons.inventory_2_outlined),
                  ),
                if (canRemote)
                  IconButton(
                    tooltip: l10n.tr('sales_history_refresh'),
                    onPressed: () => _onRefresh(auth, true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            )
          : null,
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
    final parkedBanner =
        _parkedQueueBanner(context, auth, l10n, colorScheme, textTheme);

    if (!auth.staffAccess.allowsSalesHistory) {
      final raw = sales.salesHistory;
      final filtered = _applyDateFilter(raw);
      return _bodyWithDateFilter(
        l10n,
        _salesScrollable(
          context,
          filtered,
          colorScheme,
          textTheme,
          l10n,
          canRemote: false,
          onRefresh: null,
          sourceCountBeforeFilter: raw.length,
        ),
        belowFilter: parkedBanner,
      );
    }
    if (auth.posSession == null || _remoteFuture == null) {
      final raw = sales.salesHistory;
      final filtered = _applyDateFilter(raw);
      return _bodyWithDateFilter(
        l10n,
        Column(
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
                filtered,
                colorScheme,
                textTheme,
                l10n,
                canRemote: false,
                onRefresh: null,
                sourceCountBeforeFilter: raw.length,
              ),
            ),
          ],
        ),
        belowFilter: parkedBanner,
      );
    }

    return _bodyWithDateFilter(
      l10n,
      FutureBuilder<GuilgeeListResult>(
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
            final filtered = _applyDateFilter(merged);
            return _salesScrollable(
              context,
              filtered,
              colorScheme,
              textTheme,
              l10n,
              canRemote: canRemote,
              onRefresh: canRemote ? () => _onRefresh(auth, true) : null,
              sourceCountBeforeFilter: merged.length,
            );
          }
          if (result != null && !result.success) {
            final raw = sales.salesHistory;
            final filtered = _applyDateFilter(raw);
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
                              result.error ??
                                  l10n.tr('sales_history_load_error'),
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
                    filtered,
                    colorScheme,
                    textTheme,
                    l10n,
                    canRemote: canRemote,
                    onRefresh: canRemote ? () => _onRefresh(auth, true) : null,
                    sourceCountBeforeFilter: raw.length,
                  ),
                ),
              ],
            );
          }
          final raw = sales.salesHistory;
          final filtered = _applyDateFilter(raw);
          return _salesScrollable(
            context,
            filtered,
            colorScheme,
            textTheme,
            l10n,
            canRemote: canRemote,
            onRefresh: canRemote ? () => _onRefresh(auth, true) : null,
            sourceCountBeforeFilter: raw.length,
          );
        },
      ),
      belowFilter: parkedBanner,
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
    required int sourceCountBeforeFilter,
  }) {
    final filteredEmpty = list.isEmpty &&
        sourceCountBeforeFilter > 0 &&
        (_filterYear != null);
    if (list.isEmpty) {
      final empty = _emptyState(
        colorScheme,
        textTheme,
        l10n,
        filteredEmpty: filteredEmpty,
      );
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
    AppLocalizations l10n, {
    bool filteredEmpty = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: filteredEmpty
                    ? colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.8)
                    : colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                filteredEmpty
                    ? Icons.filter_alt_outlined
                    : Icons.receipt_long_rounded,
                size: 56,
                color: filteredEmpty
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              filteredEmpty
                  ? l10n.tr('sales_filter_no_matches')
                  : l10n.tr('no_sales_history'),
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            if (!filteredEmpty) ...[
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
          ],
        ),
      ),
    );
  }

  List<_DateGroup> _groupSalesByDate(List<CompletedSale> sales) {
    final groups = <DateTime, List<CompletedSale>>{};

    for (final sale in sales) {
      final local = sale.timestamp.toLocal();
      final date = DateTime(local.year, local.month, local.day);
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
    final lang = Localizations.localeOf(context).languageCode;
    final paymentLabel = lang == 'mn'
        ? PaymentDisplayConfig.labelMn(sale.paymentMethod)
        : PaymentDisplayConfig.labelEn(sale.paymentMethod);
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
        onTap: () => showPOSCompletedSaleSheet(context, sale, l10n),
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
                          '${l10n.tr('sales_history_time')}: ${MongolianDateFormatter.formatTime(sale.timestamp, seconds: true)}',
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
                    onPressed: () => showPOSCompletedSaleSheet(context, sale, l10n),
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

}
