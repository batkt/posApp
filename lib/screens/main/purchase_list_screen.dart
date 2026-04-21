import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../services/hudaldan_avalt_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_date_range_picker.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';

/// Web parity: `barimtiinJagsaalt` tab **Худалдан авалт** (`/orlogoZarlagiinTuukh`).
class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

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
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _pickRange() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showAppDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: l10n.tr('date_picker_range_help'),
      cancelText: l10n.tr('date_picker_cancel'),
      confirmText: l10n.tr('date_picker_confirm'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        ),
      );
      _page = 1;
    });
    await _load(reset: true);
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
              title: Text(l10n.tr('menu_hudaldan_avalt')),
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
            child: OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                MongolianDateFormatter.formatDateRangeLine(
                  _range.start,
                  _range.end,
                ),
              ),
            ),
          ),
          if (!widget.showAppBar)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loading ? null : () => _load(reset: true),
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
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              r.khariltsagchiinNer.isEmpty ? '—' : r.khariltsagchiinNer,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${MongolianDateFormatter.formatDateYmdWords(ognooLocal)} ${MongolianDateFormatter.formatTime(ognooLocal)} · ${_khelberMn(r.khelber)} · ${l10n.tr('hudaldan_lines')}: ${r.lineQtySum.toStringAsFixed(0)}',
              style: textTheme.bodySmall,
            ),
            trailing: Text(
              MntAmountFormatter.formatTugrik(r.niitDun),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ),
        );
      },
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
