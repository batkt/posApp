import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../services/toololt_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mongolian_date_formatter.dart';

/// Тооллогын түүх — `GET /toollogiinJagsaaltAvya`.
class ToololtScreen extends StatefulWidget {
  const ToololtScreen({super.key});

  @override
  State<ToololtScreen> createState() => _ToololtScreenState();
}

class _ToololtScreenState extends State<ToololtScreen> {
  Future<ToololtListResult>? _future;

  void _refresh() {
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) {
      setState(() => _future = null);
      return;
    }
    setState(() {
      _future = toololtService.listToollogs(
        baiguullagiinId: pos.baiguullagiinId,
        salbariinId: pos.salbariinId,
      );
    });
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<ToololtListResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snap.data;
          if (r == null || !r.success) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  r?.error ?? l10n.tr('toololt_load_error'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (r.rows.isEmpty) {
            return Center(child: Text(l10n.tr('toololt_empty')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: r.rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final row = r.rows[i];
              final active = row.tuluv.toLowerCase().contains('ekhelsen');
              return Material(
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
              );
            },
          );
        },
      ),
    );
  }
}
