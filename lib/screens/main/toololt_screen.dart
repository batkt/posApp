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
import '../../utils/app_date_range_picker.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import '../../widgets/barcode_scan_sheet.dart';

/// Holds dialog search string across [StatefulBuilder] rebuilds.
class _SearchHolder {
  _SearchHolder(this.value);
  String value;
}

/// Идэвхтэй тооллого (вэб `khyanalt/aguulakh/toollogo`).
class ToololtScreen extends StatefulWidget {
  const ToololtScreen({super.key, this.showAppBar = true});

  /// When [MainScreen] already shows [menu_toololt] in its app bar, set false to avoid a duplicate title.
  final bool showAppBar;

  @override
  State<ToololtScreen> createState() => _ToololtScreenState();
}

class _ToololtScreenState extends State<ToololtScreen> {
  static const int _pageSize = 50;

  Future<ToololtActiveFetchResult>? _future;
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

  Future<void> _scanBarcodeToSearch(BuildContext context) async {
    final code = await showBarcodeScanSheet(context);
    final v = code?.trim();
    if (v == null || v.isEmpty) return;
    if (!context.mounted) return;
    _searchDebounce?.cancel();
    _searchController.text = v;
    setState(() {
      _lineSearch = v;
      _activePage = 1;
    });
    await _refreshAndWait();
  }

  Future<ToololtActiveFetchResult> _load() async {
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) {
      throw StateError('no_session');
    }
    return toololtService.fetchActiveToollogo(
      baiguullagiinId: pos.baiguullagiinId,
      salbariinId: pos.salbariinId,
      page: _activePage,
      pageSize: _pageSize,
      khaikhUtga: _lineSearch.isEmpty ? null : _lineSearch,
    );
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

  Future<void> _openStartSheet() async {
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) return;
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width,
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: _ToololtStartSheet(
            pos: pos,
            l10n: l10n,
            onDone: () {
              Navigator.pop(ctx);
              _refresh();
            },
          ),
        );
      },
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final rowL10n = AppLocalizations.of(ctx);
        final colorScheme = Theme.of(ctx).colorScheme;
        final textTheme = Theme.of(ctx).textTheme;
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        final z = line.zoruu;
        final zParts = <String>[];
        if (z != null) {
          void addIf(String label, dynamic v) {
            if (v == null) return;
            final n = v is num ? v.toDouble() : double.tryParse(v.toString());
            if (n == null || n == 0) return;
            zParts.add('$label: ${MntAmountFormatter.format(n)}');
          }

          addIf('Дутуу', z['dutuuToo']);
          addIf('Илүү', z['iluuToo']);
        }

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rowL10n.tr('toololt_line_info_title'),
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  line.ner,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (line.code.isNotEmpty)
                      Chip(
                        avatar: Icon(
                          Icons.tag_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        label: Text('Код: ${line.code}'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (line.barCode != null && line.barCode!.trim().isNotEmpty)
                      Chip(
                        avatar: Icon(
                          Icons.qr_code_2_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        label: Text('Баркод: ${line.barCode}'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.85,
                  children: [
                    _ToololtMetricTile(
                      label: 'Үлдэгдэл',
                      value: MntAmountFormatter.format(line.etssiinUldegdel),
                    ),
                    _ToololtMetricTile(
                      label: 'Тоолсон',
                      value: MntAmountFormatter.format(line.toolsonToo),
                    ),
                    _ToololtMetricTile(
                      label: 'Худалдах үнэ',
                      value: MntAmountFormatter.formatTugrik(
                          line.negjKhudaldakhUne),
                    ),
                    _ToololtMetricTile(
                      label: 'Нэгж өртөг',
                      value: MntAmountFormatter.formatTugrik(line.negjUrtugUne),
                    ),
                  ],
                ),
                if (zParts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Material(
                    color: colorScheme.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: colorScheme.error,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              zParts.join(' · '),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(MaterialLocalizations.of(ctx).closeButtonLabel),
                ),
              ],
            ),
          ),
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
        appBar: widget.showAppBar
            ? AppBar(title: Text(l10n.tr('menu_toololt')))
            : null,
        body: Center(child: Text(l10n.tr('toololt_no_session'))),
      );
    }

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.tr('menu_toololt')),
            )
          : null,
      bottomNavigationBar: FutureBuilder<ToololtActiveFetchResult>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final hasActive = d != null && d.success && d.hasActive;
          if (hasActive) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: _openStartSheet,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.tr('toololt_start_count')),
              ),
            ),
          );
        },
      ),
      body: FutureBuilder<ToololtActiveFetchResult>(
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
          final session = data.session;

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
                      onChanged: (v) {
                        setState(() {});
                        _scheduleSearch(v);
                      },
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
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.tr('toololt_scan_barcode'),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              onPressed: () => _scanBarcodeToSearch(context),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchDebounce?.cancel();
                                  _searchController.clear();
                                  setState(() {
                                    _lineSearch = '';
                                    _activePage = 1;
                                  });
                                  _refresh();
                                },
                              ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!data.success)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        data.error ?? l10n.tr('toololt_load_error'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  )
                else if (session != null)
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
                      totalPages: session.totalPageCount,
                      onPrevPage: session.khuudasniiDugaar > 1
                          ? () {
                              setState(() {
                                _activePage = session.khuudasniiDugaar - 1;
                              });
                              _refresh();
                            }
                          : null,
                      onNextPage:
                          session.khuudasniiDugaar < session.totalPageCount
                              ? () {
                                  setState(() {
                                    _activePage = session.khuudasniiDugaar + 1;
                                  });
                                  _refresh();
                                }
                              : null,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
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
    final qty = line.toolsonToo;
    if (qty <= 0) return 0;
    // Primary: `urtugUne` parsed into [ToololtBaraaLine.negjUrtugUne] in fromJson.
    var unitCost = line.negjUrtugUne;
    if (unitCost <= 0) {
      final z = line.zoruu;
      if (z == null) return 0;
      unitCost = _asNum(z['urtugUne']) > 0
          ? _asNum(z['urtugUne'])
          : _asNum(z['negjUrtug']) > 0
              ? _asNum(z['negjUrtug'])
              : _asNum(z['costPrice']);
    }
    if (unitCost <= 0) return 0;
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  session.ner.isNotEmpty ? session.ner : session.turul,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
                  _ToololtMetricTile(
                    label: l10n.tr('toololt_metric_total_lines'),
                    value: '${session.niitMur}',
                  ),
                  _ToololtMetricTile(
                    label: l10n.tr('toololt_metric_uncounted_products'),
                    value: '${session.toologdooguiBaraaniiToo}',
                  ),
                  _ToololtMetricTile(
                    label: l10n.tr('toololt_metric_retail_sum'),
                    value:
                        MntAmountFormatter.formatTugrik(session.niitMungunDun),
                  ),
                  _ToololtMetricTile(
                    label: l10n.tr('toololt_metric_cost_sum'),
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
                  final fieldHPad = tight ? 4.0 : 6.0;
                  final fieldVPad = tight ? 2.0 : 4.0;

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
                                l10n.tr('toololt_table_no'),
                                textAlign: TextAlign.start,
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: m.nameFlex,
                              child: Text(
                                l10n.tr('toololt_table_name'),
                                textAlign: TextAlign.start,
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: m.stockFlex,
                              child: Text(
                                l10n.tr('toololt_table_stock'),
                                textAlign: TextAlign.center,
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: m.countFlex,
                              child: Text(
                                l10n.tr('toololt_table_counted'),
                                textAlign: TextAlign.center,
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
                            border:
                                Border.all(color: colorScheme.outlineVariant),
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
                                          textAlign: TextAlign.start,
                                          style:
                                              textTheme.labelMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: m.nameFlex,
                                        child: Text(
                                          line.ner,
                                          textAlign: TextAlign.start,
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
                                          textAlign: TextAlign.center,
                                          style: textTheme.bodyMedium,
                                        ),
                                      ),
                                      Expanded(
                                        flex: m.countFlex,
                                        child: TextFormField(
                                          key: ValueKey(
                                            '${line.code}_${line.toolsonToo}',
                                          ),
                                          initialValue:
                                              MntAmountFormatter.format(
                                            line.toolsonToo,
                                          ),
                                          style: textTheme.bodySmall,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'[0-9.,]'),
                                            ),
                                          ],
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: fieldHPad,
                                              vertical: fieldVPad,
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
                          .replaceAll(
                              '{current}', '${session.khuudasniiDugaar}')
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      child: Text(l10n.tr('toololt_cancel_count')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onComplete,
                      child: Text(l10n.tr('toololt_complete')),
                    ),
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
    final l10n = widget.l10n;
    final picked = await showAppDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: l10n.tr('date_picker_range_help'),
      cancelText: l10n.tr('date_picker_cancel'),
      confirmText: l10n.tr('date_picker_confirm'),
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
                            hintText:
                                widget.l10n.tr('baraa_catalog_search_hint'),
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
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final r = snap.data!;
                        if (!r.success || r.products.isEmpty) {
                          return Center(
                              child:
                                  Text(widget.l10n.tr('baraa_catalog_empty')));
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
                              title: Text(p.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
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
        SnackBar(
            content: Text(res.error ?? widget.l10n.tr('toololt_action_error'))),
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
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.tr('toololt_start_count'),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.tr('toololt_start_name'),
                hintText: l10n.tr('toololt_start_name_hint'),
                filled: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(
                  l10n.tr('toololt_start_dates'),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  MongolianDateFormatter.formatDateRangeLine(
                    _range.start,
                    _range.end,
                  ),
                  style: textTheme.bodyMedium,
                ),
                trailing: Icon(
                  Icons.date_range_rounded,
                  color: scheme.primary,
                ),
                onTap: _pickRange,
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.tr('toololt_start_type'),
                filled: true,
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _turul,
                  isExpanded: true,
                  isDense: true,
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
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickProducts,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(
                  '${l10n.tr('toololt_pick_products')} (${l10n.tr('toololt_selected_n').replaceAll('{n}', '${_codes.length}')})',
                ),
              ),
            ],
            if (_turul == 'Ангилал') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickCategories,
                icon: const Icon(Icons.category_outlined),
                label: Text(
                  '${l10n.tr('toololt_pick_categories')} (${l10n.tr('toololt_selected_n').replaceAll('{n}', '${_angilal.length}')})',
                ),
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              title: Text(
                l10n.tr('toololt_start_include_zero_stock'),
                style: textTheme.bodyLarge,
              ),
              value: _zeroStock,
              onChanged: (v) => setState(() => _zeroStock = v),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              title: Text(
                l10n.tr('toololt_start_prefill_counts'),
                style: textTheme.bodyLarge,
              ),
              value: _prefill,
              onChanged: (v) => setState(() => _prefill = v),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
