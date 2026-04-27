import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_model.dart';
import '../models/inventory_model.dart';
import '../models/locale_model.dart';
import '../models/sales_model.dart';
import '../services/guilgee_service.dart';
import '../utils/mnt_amount_formatter.dart';
import '../utils/mongolian_date_formatter.dart';

void _restockAndClearCart(BuildContext context, SalesModel sales) {
  final inventory = context.read<InventoryModel>();
  for (final line in sales.currentSaleItems) {
    inventory.restock(line.product.id, line.quantity);
  }
  sales.clearSale();
}

/// Parked `guilgeeniiTuukh` (`tuluv: 0`) — same flow as web **Хүлээлгэ** list + recall.
Future<void> showParkedGuilgeeSheet(BuildContext parentContext) async {
  final auth = parentContext.read<AuthModel>();
  if (!auth.canSubmitPosSales || auth.posSession == null) return;

  await showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ParkedGuilgeeSheetShell(parentContext: parentContext),
  );
}

class _ParkedGuilgeeSheetShell extends StatefulWidget {
  const _ParkedGuilgeeSheetShell({required this.parentContext});

  final BuildContext parentContext;

  @override
  State<_ParkedGuilgeeSheetShell> createState() =>
      _ParkedGuilgeeSheetShellState();
}

class _ParkedGuilgeeSheetShellState extends State<_ParkedGuilgeeSheetShell> {
  late Future<ParkedGuilgeeListResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ParkedGuilgeeListResult> _load() {
    final auth = widget.parentContext.read<AuthModel>();
    final s = auth.posSession!;
    return guilgeeService.listParkedGuilgeeniiTuukh(
      baiguullagiinId: s.baiguullagiinId,
      salbariinId: s.salbariinId,
    );
  }

  Future<void> _onRefresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  Future<void> _confirmDeleteParked(
    BuildContext sheetContext,
    ParkedGuilgeeRow row,
  ) async {
    final l10n = AppLocalizations.of(sheetContext);
    final ok = await showDialog<bool>(
      context: sheetContext,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.tr('pos_park_delete_title')),
        content: Text(l10n.tr('pos_park_delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(l10n.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dCtx).colorScheme.error,
              foregroundColor: Theme.of(dCtx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.tr('pos_park_delete')),
          ),
        ],
      ),
    );
    if (ok != true || !sheetContext.mounted) return;
    if (row.mongoId.isEmpty) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(l10n.tr('pos_park_delete_failed'))),
      );
      return;
    }

    final deleted = await guilgeeService.deleteGuilgeeniiTuukhById(row.mongoId);
    if (!sheetContext.mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(l10n.tr('pos_park_delete_failed'))),
      );
      return;
    }
    ScaffoldMessenger.of(sheetContext).showSnackBar(
      SnackBar(content: Text(l10n.tr('pos_park_delete_success'))),
    );
    await _onRefresh();
  }

  Future<void> _recallParkedSale(
    BuildContext sheetContext,
    ParkedGuilgeeRow row,
  ) async {
    final l10n = AppLocalizations.of(sheetContext);
    final sales = sheetContext.read<SalesModel>();

    if (!sheetContext.mounted) return;
    final confirm = await showDialog<bool>(
      context: sheetContext,
      builder: (dCtx) => AlertDialog(
        title: Text(l10n.tr('pos_park_recall_title')),
        content: Text(l10n.tr('pos_park_recall_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text(l10n.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(l10n.tr('date_picker_confirm')),
          ),
        ],
      ),
    );
    if (confirm != true || !sheetContext.mounted) return;

    if (!sales.isSaleEmpty) {
      final replace = await showDialog<bool>(
        context: sheetContext,
        builder: (dCtx) => AlertDialog(
          title: Text(l10n.tr('pos_park_recall_replace_title')),
          content: Text(l10n.tr('pos_park_recall_replace_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(l10n.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(l10n.tr('date_picker_confirm')),
            ),
          ],
        ),
      );
      if (replace != true || !sheetContext.mounted) return;
      _restockAndClearCart(sheetContext, sales);
    }

    final deleted = await guilgeeService.deleteGuilgeeniiTuukhById(row.mongoId);
    if (!sheetContext.mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(l10n.tr('pos_park_recall_failed'))),
      );
      return;
    }

    final lines = saleItemsFromParkedGuilgeeDoc(row.doc);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(l10n.tr('pos_park_recall_failed'))),
      );
      return;
    }

    final inventory = sheetContext.read<InventoryModel>();
    for (final line in lines) {
      if (line.quantity > 0) {
        inventory.deductStock(line.product.id, line.quantity);
      }
    }
    sales.restoreParkedSale(lines, guilgeeniiDugaar: row.guilgeeniiDugaar);

    if (sheetContext.mounted) Navigator.pop(sheetContext);
    if (widget.parentContext.mounted) {
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(content: Text(l10n.tr('pos_park_recalled'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.38,
      maxChildSize: 0.94,
      builder: (ctx, scrollController) {
        return Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            l10n.tr('pos_park_modal_title'),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant),
              Expanded(
                child: FutureBuilder<ParkedGuilgeeListResult>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: SelectableText(
                            snap.error.toString(),
                            textAlign: TextAlign.center,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    final r = snap.data;
                    if (r == null || !r.success) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: cs.error.withValues(alpha: 0.85),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                r?.error ?? l10n.tr('pos_park_load_error'),
                                textAlign: TextAlign.center,
                                style: tt.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (r.rows.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 56,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.tr('pos_park_none'),
                                textAlign: TextAlign.center,
                                style: tt.titleMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: r.rows.length,
                        itemBuilder: (_, i) {
                          final row = r.rows[i];
                          final whenStr =
                              '${MongolianDateFormatter.formatSalesHistorySectionDate(row.ognoo)} · '
                              '${MongolianDateFormatter.formatTime(row.ognoo, seconds: false)}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: cs.surfaceContainerLow,
                              elevation: 0,
                              borderRadius: BorderRadius.circular(16),
                              // [stretch] + ListView unbounded height causes RenderFlex failures (Flutter web).
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                        left: Radius.circular(16),
                                      ),
                                      onTap: () => _recallParkedSale(ctx, row),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: cs.primaryContainer
                                                    .withValues(alpha: 0.55),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                child: Icon(
                                                  Icons
                                                      .pause_circle_filled_rounded,
                                                  color: cs.primary,
                                                  size: 26,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    row.guilgeeniiDugaar,
                                                    style: tt.titleMedium
                                                        ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    whenStr,
                                                    style:
                                                        tt.bodySmall?.copyWith(
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    l10n
                                                        .tr('pos_park_line_count')
                                                        .replaceAll(
                                                          '{n}',
                                                          '${row.lineCount}',
                                                        ),
                                                    style:
                                                        tt.bodyMedium?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    MntAmountFormatter
                                                        .formatTugrikSpaced(
                                                      row.niitUne,
                                                    ),
                                                    style: tt.titleMedium
                                                        ?.copyWith(
                                                      color: cs.primary,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: IconButton(
                                      tooltip: l10n.tr('pos_park_delete'),
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: cs.error,
                                      ),
                                      onPressed: () =>
                                          _confirmDeleteParked(ctx, row),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
