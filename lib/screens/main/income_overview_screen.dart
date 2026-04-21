import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../services/hynalt_tailan_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_date_range_picker.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';

/// Web parity: `/khyanalt/hynalt` — summary cards + “Их зарагдсан” table (Орлого column).
class IncomeOverviewScreen extends StatefulWidget {
  const IncomeOverviewScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<IncomeOverviewScreen> createState() => _IncomeOverviewScreenState();
}

class _IncomeOverviewScreenState extends State<IncomeOverviewScreen> {
  final HynaltTailanService _svc = HynaltTailanService();
  late DateTimeRange _range;

  DashboardMedeelelResult? _dash;
  BorluulaltTopResult? _top;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
    });
    await _load();
  }

  Future<void> _load() async {
    final session = context.read<AuthModel>().posSession;
    if (session == null) {
      setState(() {
        _error = AppLocalizations.of(context).tr('toololt_no_session');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final dash = await _svc.fetchDashboardMedeelel(
      baiguullagiinId: session.baiguullagiinId,
      salbariinId: session.salbariinId,
      ekhlekh: _range.start,
      duusakh: _range.end,
    );
    final top = await _svc.fetchBorluulaltTop(
      baiguullagiinId: session.baiguullagiinId,
      salbariinId: session.salbariinId,
      ekhlekh: _range.start,
      duusakh: _range.end,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _dash = dash;
      _top = top;
      if (!dash.ok) _error = dash.error;
      if (top.ok == false && _error == null) _error = top.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.tr('menu_orlogo')),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loading ? null : _load,
                ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.showAppBar)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: l10n.tr('action_refresh'),
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loading ? null : _load,
                ),
              ),
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                MongolianDateFormatter.formatDateRangeLine(
                  _range.start,
                  _range.end,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(
                _error!,
                style: textTheme.bodyLarge?.copyWith(color: AppColors.error),
              )
            else ...[
              if (_dash != null && _dash!.ok) ...[
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: l10n.tr('revenue'),
                        value: _dash!.borluulalt,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: l10n.tr('orlogo_profit_label'),
                        value: _dash!.ashig,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              Text(
                l10n.tr('orlogo_top_selling_title'),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (_top != null && _top!.ok && _top!.rows.isEmpty)
                Text(
                  l10n.tr('orlogo_top_empty'),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else if (_top != null && _top!.ok)
                ..._top!.rows.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        r.ner.isEmpty ? '—' : r.ner,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${l10n.tr('orlogo_col_qty')}: ${r.niitToo.toStringAsFixed(0)}',
                      ),
                      trailing: Text(
                        MntAmountFormatter.formatTugrik(r.zarsanNiitUne),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final double value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              MntAmountFormatter.formatTugrik(value),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
