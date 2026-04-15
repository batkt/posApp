import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../models/pos_session.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../services/toololt_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';

/// Holds dialog search string across [StatefulBuilder] rebuilds.
class _SearchHolder {
  _SearchHolder(this.value);
  String value;
}

class _ToololtScreenData {
  const _ToololtScreenData({
    required this.history,
    required this.active,
  });

  final ToololtListResult history;
  final ToololtActiveFetchResult active;
}

/// Тооллогын түүх + идэвхтэй тооллого (вэб `khyanalt/aguulakh/toollogo`).
class ToololtScreen extends StatefulWidget {
  const ToololtScreen({super.key});

  @override
  State<ToololtScreen> createState() => _ToololtScreenState();
}

class _ToololtScreenState extends State<ToololtScreen> {
  static const int _pageSize = 50;

  Future<_ToololtScreenData>? _future;
  final TextEditingController _searchController = TextEditingController();
  String _lineSearch = '';
  int _activePage = 1;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearch(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _lineSearch = v.trim();
        _activePage = 1;
      });
      _refresh();
    });
  }

  Future<_ToololtScreenData> _load() async {
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) {
      throw StateError('no_session');
    }
    final history = await toololtService.listToollogs(
      baiguullagiinId: pos.baiguullagiinId,
      salbariinId: pos.salbariinId,
      search: _lineSearch.isEmpty ? null : _lineSearch,
    );
    final active = await toololtService.fetchActiveToollogo(
      baiguullagiinId: pos.baiguullagiinId,
      salbariinId: pos.salbariinId,
      page: _activePage,
      pageSize: _pageSize,
      khaikhUtga: _lineSearch.isEmpty ? null : _lineSearch,
    );
    return _ToololtScreenData(history: history, active: active);
  }

  void _refresh() {
    final auth = context.read<AuthModel>();
    if (auth.posSession == null) {
      setState(() {
        _future = null;
      });
      return;
    }
    setState(() {
      _future = _load();
    });
  }

  Future<void> _refreshAndWait() async {
    final auth = context.read<AuthModel>();
    if (auth.posSession == null) return;
    final f = _load();
    if (!mounted) return;
    setState(() {
      _future = f;
    });
    await f;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  String _tuluvLabel(String tuluv, AppLocalizations l10n) {
    final t = tuluv.toLowerCase();
    if (t.contains('ekhelsen') || t == 'ekhelsen') {
      return l10n.tr('toololt_status_active');
    }
    if (t.contains('duussan') || t == 'duussan') {
      return l10n.tr('toololt_status_done');
    }
    return tuluv.isEmpty ? '—' : tuluv;
  }

  Future<void> _openStartSheet() async {
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) return;
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _ToololtStartSheet(
          pos: pos,
          l10n: l10n,
          onDone: () {
            Navigator.pop(ctx);
            _refresh();
          },
        ),
      ),
    );
  }

  Future<void> _saveLineQty(
    ToololtActiveSession session,
    ToololtBaraaLine line,
    String rawText,
  ) async {
    final l10n = AppLocalizations.of(context);
    final v = double.tryParse(rawText.replaceAll(',', '.').trim());
    if (v == null || v < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('toololt_action_error'))),
      );
      return;
    }
    final res = await toololtService.saveCountedQty(
      toollogoId: session.id,
      code: line.code,
      too: v,
    );
    if (!mounted) return;
    if (res.success) {
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? l10n.tr('toololt_action_error'))),
      );
    }
  }

  Future<void> _showLineInfoModal(ToololtBaraaLine line) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final textTheme = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: Text(line.ner),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${line.code}${line.barCode != null && line.barCode!.isNotEmpty ? ' · ${line.barCode}' : ''}',
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _PriceRow(
                label: 'Худалдах Үнэ',
                value: MntAmountFormatter.formatTugrik(line.negjKhudaldakhUne),
              ),
              const SizedBox(height: 8),
              _PriceRow(
                label: 'Нэгж өртөг',
                value: MntAmountFormatter.formatTugrik(line.negjUrtugUne),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(ctx).closeButtonLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmComplete(ToololtActiveSession session) async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('toololt_confirm_complete_title')),
        content: Text(l10n.tr('toololt_confirm_complete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.tr('toololt_complete')),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final res = await toololtService.completeToololt(
      toollogoId: session.id,
      baiguullagiinId: pos.baiguullagiinId,
      salbariinId: pos.salbariinId,
    );
    if (!mounted) return;
    if (res.success) {
      _activePage = 1;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('toololt_status_done'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? l10n.tr('toololt_action_error'))),
      );
    }
  }

  Future<void> _confirmCancel(ToololtActiveSession session) async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('toololt_confirm_cancel_title')),
        content: Text(l10n.tr('toololt_confirm_cancel_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.tr('toololt_cancel_count')),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final res = await toololtService.cancelToololt(toollogoId: session.id);
    if (!mounted) return;
    if (res.success) {
      _activePage = 1;
      _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? l10n.tr('toololt_action_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final auth = context.watch<AuthModel>();
    final pos = auth.posSession;

    if (pos == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tr('menu_toololt'))),
        body: Center(child: Text(l10n.tr('toololt_no_session'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('menu_toololt')),
      ),
      floatingActionButton: FutureBuilder<_ToololtScreenData>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final hasActive =
              d != null && d.active.success && d.active.hasActive;
          if (hasActive) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _openStartSheet,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.tr('toololt_start_count')),
          );
        },
      ),
      body: FutureBuilder<_ToololtScreenData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snap.error?.toString() ?? l10n.tr('toololt_load_error'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final data = snap.data!;
          final session = data.active.session;

          return RefreshIndicator(
            onRefresh: _refreshAndWait,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _scheduleSearch,
                      onSubmitted: (v) {
                        _searchDebounce?.cancel();
                        if (!mounted) return;
                        setState(() {
                          _lineSearch = v.trim();
                          _activePage = 1;
                        });
                        _refresh();
                      },
                      decoration: InputDecoration(
                        hintText: l10n.tr('toololt_search_lines'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      l10n.tr('toololt_section_active'),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (!data.active.success)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        data.active.error ?? l10n.tr('toololt_load_error'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  )
                else if (!data.active.hasActive || session == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.tr('toololt_no_active_hint'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: _ActiveCountCard(
                      l10n: l10n,
                      session: session,
                      onTapLine: _showLineInfoModal,
                      onSubmitLineFor: (line, value) =>
                          _saveLineQty(session, line, value),
                      onComplete: () => _confirmComplete(session),
                      onCancel: () => _confirmCancel(session),
                      activePage: _activePage,
                      totalPages: session.niitKhuudas < 1 ? 1 : session.niitKhuudas,
                      onPrevPage: session.khuudasniiDugaar > 1
                          ? () {
                              setState(() {
                                _activePage = session.khuudasniiDugaar - 1;
                              });
                              _refresh();
                            }
                          : null,
                      onNextPage: session.khuudasniiDugaar < session.niitKhuudas
                          ? () {
                              setState(() {
                                _activePage = session.khuudasniiDugaar + 1;
                              });
                              _refresh();
                            }
                          : null,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      l10n.tr('toololt_section_history'),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (!data.history.success)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        data.history.error ?? l10n.tr('toololt_load_error'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (data.history.rows.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(child: Text(l10n.tr('toololt_empty'))),
                  )
                else
                  SliverList.separated(
                    itemCount: data.history.rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final row = data.history.rows[i];
                      final active =
                          row.tuluv.toLowerCase().contains('ekhelsen');
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Material(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      active
                                          ? Icons.play_circle_outline_rounded
                                          : Icons.check_circle_outline_rounded,
                                      color: active
                                          ? AppColors.warning
                                          : AppColors.success,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        row.ner.isNotEmpty
                                            ? row.ner
                                            : row.turul.isNotEmpty
                                                ? row.turul
                                                : row.id,
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (active
                                                ? AppColors.warning
                                                : AppColors.success)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _tuluvLabel(row.tuluv, l10n),
                                        style: textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: active
                                              ? AppColors.warning
                                              : AppColors.success,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (row.turul.isNotEmpty && row.ner.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    row.turul,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    if (row.niitBaraa != null)
                                      Text(
                                        '${l10n.tr('toololt_total_lines')}: ${row.niitBaraa}',
                                        style: textTheme.labelMedium,
                                      ),
                                    if (row.toologdoogui != null)
                                      Text(
                                        '${l10n.tr('toololt_remaining')}: ${row.toologdoogui}',
                                        style: textTheme.labelMedium?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                                if (row.ekhelsenOgnoo != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${l10n.tr('toololt_started')}: ${MongolianDateFormatter.formatDateTime(row.ekhelsenOgnoo!)}',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (row.duussanOgnoo != null)
                                  Text(
                                    '${l10n.tr('toololt_finished')}: ${MongolianDateFormatter.formatDateTime(row.duussanOgnoo!)}',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 88)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Responsive flex for the active toololt line table: narrower name, wider numbers.
class _ToololtLineTableMetrics {
  const _ToololtLineTableMetrics({
    required this.indexWidth,
    required this.nameFlex,
    required this.stockFlex,
    required this.countFlex,
  });

  final double indexWidth;
  final int nameFlex;
  final int stockFlex;
  final int countFlex;

  static _ToololtLineTableMetrics forRowWidth(double w) {
    if (w < 300) {
      return const _ToololtLineTableMetrics(
        indexWidth: 22,
        nameFlex: 3,
        stockFlex: 5,
        countFlex: 6,
      );
    }
    if (w < 380) {
      return const _ToololtLineTableMetrics(
        indexWidth: 24,
        nameFlex: 3,
        stockFlex: 5,
        countFlex: 6,
      );
    }
    if (w < 520) {
      return const _ToololtLineTableMetrics(
        indexWidth: 28,
        nameFlex: 4,
        stockFlex: 5,
        countFlex: 6,
      );
    }
    return const _ToololtLineTableMetrics(
      indexWidth: 32,
      nameFlex: 5,
      stockFlex: 6,
      countFlex: 7,
    );
  }
}

class _ActiveCountCard extends StatelessWidget {
  const _ActiveCountCard({
    required this.l10n,
    required this.session,
    required this.onTapLine,
    required this.onSubmitLineFor,
    required this.onComplete,
    required this.onCancel,
    required this.activePage,
    required this.totalPages,
    this.onPrevPage,
    this.onNextPage,
  });

  final AppLocalizations l10n;
  final ToololtActiveSession session;
  final Future<void> Function(ToololtBaraaLine) onTapLine;
  final Future<void> Function(ToololtBaraaLine, String) onSubmitLineFor;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final int activePage;
  final int totalPages;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;

  double _asNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  double _lineCostTotal(ToololtBaraaLine line) {
    final z = line.zoruu;
    if (z == null) return 0;
    final qty = line.toolsonToo;
    final unitCost =
        _asNum(z['negjUrtug']) > 0
            ? _asNum(z['negjUrtug'])
            : _asNum(z['urtugUne']) > 0
            ? _asNum(z['urtugUne'])
            : _asNum(z['costPrice']);
    if (unitCost <= 0 || qty <= 0) return 0;
    return unitCost * qty;
  }

  double _totalCostAmount() {
    var sum = 0.0;
    for (final line in session.lines) {
      sum += _lineCostTotal(line);
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.ner.isNotEmpty ? session.ner : session.turul,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onCancel,
                    child: Text(l10n.tr('toololt_cancel_count')),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: onComplete,
                    child: Text(l10n.tr('toololt_complete')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _ToololtMetricTile(label: 'Нийт бараа', value: '${session.niitMur}'),
                  _ToololtMetricTile(
                    label: 'Үлдсэн',
                    value: '${session.toologdooguiBaraaniiToo}',
                  ),
                  _ToololtMetricTile(
                    label: 'Худалдах үнэ',
                    value: MntAmountFormatter.formatTugrik(session.niitMungunDun),
                  ),
                  _ToololtMetricTile(
                    label: 'Нэгж өртөг',
                    value: MntAmountFormatter.formatTugrik(_totalCostAmount()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final m = _ToololtLineTableMetrics.forRowWidth(
                    constraints.maxWidth,
                  );
                  final h = MediaQuery.sizeOf(context).height;
                  final tableHeight = (h * 0.32).clamp(220.0, 420.0);
                  final tight = constraints.maxWidth < 380;
                  final fieldPad = tight ? 6.0 : 8.0;

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: m.indexWidth,
                              child: Text(
                                '№',
                                textAlign: TextAlign.center,
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: m.nameFlex,
                              child: Text(
                                'Нэр',
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: m.stockFlex,
                              child: Text(
                                'Үлдэгдэл',
                                textAlign: TextAlign.right,
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: m.countFlex,
                              child: Text(
                                'Тоолсон',
                                textAlign: TextAlign.right,
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: tableHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outlineVariant),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(10),
                            ),
                          ),
                          child: ListView.separated(
                            itemCount: session.lines.length,
                            itemBuilder: (context, i) {
                              final line = session.lines[i];
                              return InkWell(
                                onTap: () => onTapLine(line),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: m.indexWidth,
                                        child: Text(
                                          '${i + 1}',
                                          textAlign: TextAlign.center,
                                          style: textTheme.labelMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: m.nameFlex,
                                        child: Text(
                                          line.ner,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: m.stockFlex,
                                        child: Text(
                                          MntAmountFormatter.format(
                                            line.etssiinUldegdel,
                                          ),
                                          textAlign: TextAlign.right,
                                          style: textTheme.bodyMedium,
                                        ),
                                      ),
                                      Expanded(
                                        flex: m.countFlex,
                                        child: TextFormField(
                                          key: ValueKey(
                                            '${line.code}_${line.toolsonToo}',
                                          ),
                                          initialValue: MntAmountFormatter.format(
                                            line.toolsonToo,
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'[0-9.,]'),
                                            ),
                                          ],
                                          textAlign: TextAlign.right,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: fieldPad,
                                              vertical: fieldPad,
                                            ),
                                            border: const OutlineInputBorder(),
                                          ),
                                          onFieldSubmitted: (v) {
                                            onSubmitLineFor(line, v);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 1,
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: onPrevPage,
                    child: Text(l10n.tr('toololt_prev')),
                  ),
                  Expanded(
                    child: Text(
                      l10n
                          .tr('toololt_page')
                          .replaceAll('{current}', '${session.khuudasniiDugaar}')
                          .replaceAll('{total}', '$totalPages'),
                      textAlign: TextAlign.center,
                      style: textTheme.labelMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: onNextPage,
                    child: Text(l10n.tr('toololt_next')),
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

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ToololtMetricTile extends StatelessWidget {
  const _ToololtMetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToololtStartSheet extends StatefulWidget {
  const _ToololtStartSheet({
    required this.pos,
    required this.l10n,
    required this.onDone,
  });

  final PosSession pos;
  final AppLocalizations l10n;
  final VoidCallback onDone;

  @override
  State<_ToololtStartSheet> createState() => _ToololtStartSheetState();
}

class _ToololtStartSheetState extends State<_ToololtStartSheet> {
  final _nameCtrl = TextEditingController();
  late DateTimeRange _range = () {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month, n.day),
      end: DateTime(n.year, n.month, n.day, 23, 59, 59),
    );
  }();
  bool _zeroStock = true;
  bool _prefill = true;
  String _turul = 'Бүх бараа';
  final Set<String> _codes = {};
  final Set<String> _angilal = {};
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _dayStart(DateTime d) {
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day 00:00:00';
  }

  String _dayEnd(DateTime d) {
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day 23:59:59';
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  Future<void> _pickProducts() async {
    final productService = ProductService();
    final searchCtrl = TextEditingController();
    final picked = <String>{..._codes};
    final queryHolder = _SearchHolder('');
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: Text(widget.l10n.tr('toololt_pick_products')),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: widget.l10n.tr('baraa_catalog_search_hint'),
                            prefixIcon: const Icon(Icons.search_rounded),
                          ),
                          onSubmitted: (v) {
                            queryHolder.value = v.trim();
                            setSt(() {});
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: widget.l10n.tr('sales_history_refresh'),
                        onPressed: () {
                          queryHolder.value = searchCtrl.text.trim();
                          setSt(() {});
                        },
                        icon: const Icon(Icons.search_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder(
                      key: ValueKey(queryHolder.value),
                      future: productService.getProducts(
                        search: queryHolder.value,
                        baiguullagiinId: widget.pos.baiguullagiinId,
                        salbariinId: widget.pos.salbariinId,
                        page: 1,
                        limit: 80,
                      ),
                      builder: (c, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final r = snap.data!;
                        if (!r.success || r.products.isEmpty) {
                          return Center(child: Text(widget.l10n.tr('baraa_catalog_empty')));
                        }
                        return ListView(
                          children: r.products.map((p) {
                            final code = p.code ?? p.id;
                            final sel = picked.contains(code);
                            return CheckboxListTile(
                              value: sel,
                              onChanged: (v) {
                                setSt(() {
                                  if (v == true) {
                                    picked.add(code);
                                  } else {
                                    picked.remove(code);
                                  }
                                });
                              },
                              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(code),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _codes
                      ..clear()
                      ..addAll(picked);
                  });
                  Navigator.pop(ctx);
                },
                child: Text(widget.l10n.tr('toololt_save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickCategories() async {
    final categoryService = CategoryService();
    final picked = <String>{..._angilal};
    final res = await categoryService.getCategories(
      baiguullagiinId: widget.pos.baiguullagiinId,
      limit: 200,
    );
    if (!mounted) return;
    if (!res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? widget.l10n.tr('toololt_action_error'))),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          return AlertDialog(
            title: Text(widget.l10n.tr('toololt_pick_categories')),
            content: SizedBox(
              width: double.maxFinite,
              height: 360,
              child: ListView(
                children: res.categories.map((cat) {
                  final a = cat.angilal;
                  final sel = picked.contains(a);
                  return CheckboxListTile(
                    value: sel,
                    onChanged: (v) {
                      setSt(() {
                        if (v == true) {
                          picked.add(a);
                        } else {
                          picked.remove(a);
                        }
                      });
                    },
                    title: Text(a),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _angilal
                      ..clear()
                      ..addAll(picked);
                  });
                  Navigator.pop(ctx);
                },
                child: Text(widget.l10n.tr('toololt_save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = widget.l10n;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('toololt_start_name'))),
      );
      return;
    }
    if (_turul == 'Бараа сонгох' && _codes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('toololt_pick_products'))),
      );
      return;
    }
    if (_turul == 'Ангилал' && _angilal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('toololt_pick_categories'))),
      );
      return;
    }
    setState(() => _submitting = true);
    final r = await toololtService.startToololt(
      baiguullagiinId: widget.pos.baiguullagiinId,
      salbariinId: widget.pos.salbariinId,
      ner: name,
      ekhlekhOgnoo: _dayStart(_range.start),
      duusakhOgnoo: _dayEnd(_range.end),
      turul: _turul,
      uldegdelteiBaraaToolohEsekh: _zeroStock,
      toogKharuulakhEsekh: _prefill,
      baraanuudCodes: _turul == 'Бараа сонгох' ? _codes.toList() : null,
      angilaluud: _turul == 'Ангилал' ? _angilal.toList() : null,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (r.success) {
      widget.onDone();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.error ?? l10n.tr('toololt_action_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.tr('toololt_start_count'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.tr('toololt_start_name'),
                hintText: l10n.tr('toololt_start_name_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.tr('toololt_start_dates')),
              subtitle: Text(
                '${_range.start.toIso8601String().split('T').first} — ${_range.end.toIso8601String().split('T').first}',
              ),
              trailing: const Icon(Icons.date_range_rounded),
              onTap: _pickRange,
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.tr('toololt_start_type'),
                border: const OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _turul,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'Бүх бараа',
                      child: Text(l10n.tr('toololt_type_all')),
                    ),
                    DropdownMenuItem(
                      value: 'Бараа сонгох',
                      child: Text(l10n.tr('toololt_type_pick_products')),
                    ),
                    DropdownMenuItem(
                      value: 'Ангилал',
                      child: Text(l10n.tr('toololt_type_pick_categories')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _turul = v);
                  },
                ),
              ),
            ),
            if (_turul == 'Бараа сонгох') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickProducts,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(
                  '${l10n.tr('toololt_pick_products')} (${l10n.tr('toololt_selected_n').replaceAll('{n}', '${_codes.length}')})',
                ),
              ),
            ],
            if (_turul == 'Ангилал') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickCategories,
                icon: const Icon(Icons.category_outlined),
                label: Text(
                  '${l10n.tr('toololt_pick_categories')} (${l10n.tr('toololt_selected_n').replaceAll('{n}', '${_angilal.length}')})',
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.tr('toololt_start_include_zero_stock')),
              value: _zeroStock,
              onChanged: (v) => setState(() => _zeroStock = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.tr('toololt_start_prefill_counts')),
              value: _prefill,
              onChanged: (v) => setState(() => _prefill = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.tr('toololt_start_count')),
            ),
            SizedBox(height: scheme.brightness == Brightness.dark ? 8 : 0),
          ],
        ),
      ),
    );
  }
}
