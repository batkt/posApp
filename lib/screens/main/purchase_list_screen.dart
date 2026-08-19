import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../services/hudaldan_avalt_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../widgets/app_date_range_filter_button.dart';

/// Web parity: `barimtiinJagsaalt` tab **Худалдан авалт** (`/orlogoZarlagiinTuukh`).
class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({
    super.key,
    this.showAppBar = true,
    this.khariltsagchiinId,
    this.customerNameForTitle,
  });

  final bool showAppBar;

  /// When set, loads only this customer's rows (same as web customer filter).
  final String? khariltsagchiinId;

  /// Shown under the app bar title when [khariltsagchiinId] is set.
  final String? customerNameForTitle;

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  final HudaldanAvaltService _svc = HudaldanAvaltService();
  late DateTimeRange _range;
  int _page = 1;
  static const _pageSize = 30;

  HudaldanAvaltPageResult? _result;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1, 0, 0, 0),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }



  Future<void> _load({bool reset = false}) async {
    final session = context.read<AuthModel>().posSession;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = HudaldanAvaltPageResult.fail(
          AppLocalizations.of(context).tr('toololt_no_session'),
        );
      });
      return;
    }

    if (reset) _page = 1;

    setState(() => _loading = true);

    final res = await _svc.fetchPage(
      baiguullagiinId: session.baiguullagiinId,
      salbariinId: session.salbariinId,
      ognooFrom: _range.start,
      ognooTo: _range.end,
      page: _page,
      pageSize: _pageSize,
      khariltsagchiinId: widget.khariltsagchiinId,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = res;
    });
  }

  String _khelberMn(String? k) {
    switch (k) {
      case 'belen':
        return 'Бэлэн';
      case 'zeel':
        return 'Зээл';
      default:
        return k ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: widget.customerNameForTitle != null &&
                      widget.customerNameForTitle!.trim().isNotEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.tr('menu_hudaldan_avalt')),
                        Text(
                          widget.customerNameForTitle!.trim(),
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Text(l10n.tr('menu_hudaldan_avalt')),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loading ? null : () => _load(reset: true),
                ),
              ],
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AppDateRangeFilterButton(
              range: _range,
              onPressed: (picked) async {
                setState(() {
                  _range = picked;
                  _page = 1;
                });
                await _load(reset: true);
              },
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _buildBody(l10n, colorScheme, textTheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final res = _result;
    if (res == null || !res.ok) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              res?.error ?? '—',
              style: textTheme.bodyLarge?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      );
    }

    if (res.rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.tr('hudaldan_avalt_empty'),
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: res.rows.length + 1,
      itemBuilder: (context, index) {
        if (index == res.rows.length) {
          return _PaginationBar(
            page: _page,
            totalPages: res.totalPages,
            onPrev: _page <= 1 || _loading
                ? null
                : () {
                    setState(() => _page -= 1);
                    _load();
                  },
            onNext: _page >= res.totalPages || _loading
                ? null
                : () {
                    setState(() => _page += 1);
                    _load();
                  },
          );
        }
        final r = res.rows[index];
        final ognooLocal = r.ognoo.toLocal();
        final dateStr =
            '${ognooLocal.year}-${ognooLocal.month.toString().padLeft(2, '0')}-${ognooLocal.day.toString().padLeft(2, '0')} ${ognooLocal.hour.toString().padLeft(2, '0')}:${ognooLocal.minute.toString().padLeft(2, '0')}';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => _PurchaseDetailSheet(row: r),
              );
            },
            title: Text(
              r.khariltsagchiinNer.isEmpty ? '—' : r.khariltsagchiinNer,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '$dateStr · ${_khelberMn(r.khelber)} · ${l10n.tr('hudaldan_lines')}: ${r.lineQtySum % 1 == 0 ? r.lineQtySum.toInt() : r.lineQtySum}',
              style: textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MntAmountFormatter.formatTugrik(r.niitDun),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PurchaseDetailSheet extends StatelessWidget {
  const _PurchaseDetailSheet({required this.row});

  final HudaldanAvaltRow row;

  String _khelberLabel(String? k) {
    switch (k?.toLowerCase()) {
      case 'belen':
        return 'Бэлэн';
      case 'zeel':
        return 'Зээл';
      case 'kart':
        return 'Карт';
      case 'qpay':
        return 'QPay';
      default:
        return k ?? 'Бэлэн';
    }
  }

  Color _khelberColor(String? k, ColorScheme cs) {
    switch (k?.toLowerCase()) {
      case 'belen':
        return Colors.green;
      case 'zeel':
        return Colors.orange;
      case 'kart':
        return cs.primary;
      case 'qpay':
        return Colors.blue;
      default:
        return cs.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ognooLocal = row.ognoo.toLocal();
    final dateStr =
        '${ognooLocal.year}-${ognooLocal.month.toString().padLeft(2, '0')}-${ognooLocal.day.toString().padLeft(2, '0')} ${ognooLocal.hour.toString().padLeft(2, '0')}:${ognooLocal.minute.toString().padLeft(2, '0')}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.khariltsagchiinNer.isEmpty
                          ? 'Худалдан авалт'
                          : row.khariltsagchiinNer,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _khelberColor(row.khelber, colorScheme)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _khelberColor(row.khelber, colorScheme)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _khelberLabel(row.khelber),
                  style: textTheme.labelSmall?.copyWith(
                    color: _khelberColor(row.khelber, colorScheme),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Барааны жагсаалт (${row.items.length})',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Нийт: ${MntAmountFormatter.formatTugrikSpaced(row.niitDun)}',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: row.items.isEmpty
                ? Center(
                    child: Text(
                      'Барааны мэдээлэл олдсонгүй',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: row.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = row.items[index];
                      final itemKhelber = item.khelber ?? row.khelber;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.ner,
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (item.code.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.code,
                                      style: textTheme.labelSmall?.copyWith(
                                        fontFamily: 'monospace',
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _InputDisplayField(
                                    label: 'Тоо ширхэг',
                                    value:
                                        '${item.too % 1 == 0 ? item.too.toInt() : item.too} ширхэг',
                                    icon: Icons.inventory_2_outlined,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InputDisplayField(
                                    label: 'Нэгж үнэ',
                                    value:
                                        MntAmountFormatter.formatTugrikSpaced(
                                            item.urtugUne),
                                    icon: Icons.sell_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _InputDisplayField(
                                    label: 'Худалдах үнэ',
                                    value:
                                        MntAmountFormatter.formatTugrikSpaced(
                                            item.zarakhUne),
                                    icon: Icons.monetization_on_outlined,
                                    isPrimary: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InputDisplayField(
                                    label: 'Төлбөрийн хэлбэр',
                                    value: _khelberLabel(itemKhelber),
                                    icon: Icons.account_balance_wallet_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Хаах'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputDisplayField extends StatelessWidget {
  const _InputDisplayField({
    required this.label,
    required this.value,
    required this.icon,
    this.isPrimary = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color:
                isPrimary ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        isPrimary ? colorScheme.primary : colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$page / $totalPages',
              style: textTheme.titleSmall,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
