import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../services/tailan_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_date_range_picker.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../widgets/app_date_range_filter_button.dart';

/// Single consolidated “closing” report: totals by payment method for the period.
/// Uses `POST /borluulaltiinTailanKhelbereerAvya` (same as web POS).
class TailanScreen extends StatefulWidget {
  const TailanScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<TailanScreen> createState() => _TailanScreenState();
}

class _TailanScreenState extends State<TailanScreen> {
  final TailanService _tailan = TailanService();
  late DateTimeRange _range;
  Future<TailanPostResult>? _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
    _future = _load();
  }

  Future<TailanPostResult> _load() async {
    final session = context.read<AuthModel>().posSession;
    if (session == null) {
      return TailanPostResult.fail('no_session');
    }
    return _tailan.borluulaltiinTailanKhelbereerAvya(
      baiguullagiinId: session.baiguullagiinId,
      salbariinId: session.salbariinId,
      ekhlekh: _range.start,
      duusakh: _range.end,
    );
  }

  Future<void> _pickRange() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
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
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: Text(l10n.tr('tailan_menu')))
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.tr('tailan_consolidated_subtitle'),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AppDateRangeFilterButton(
              range: _range,
              onPressed: (picked) {
                setState(() {
                  _range = picked;
                  _future = _load();
                });
              },
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: FutureBuilder<TailanPostResult>(
              key: ValueKey<Object>('${_range.start}_${_range.end}'),
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final r = snap.data;
                if (r == null || !r.ok) {
                  final msg = r?.error == 'no_session'
                      ? l10n.tr('toololt_no_session')
                      : (r?.error ?? '—');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        msg,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    final f = _load();
                    setState(() => _future = f);
                    await f;
                  },
                  child: _NegtgelPaymentList(data: r.data),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NegtgelPaymentList extends StatelessWidget {
  const _NegtgelPaymentList({required this.data});

  final dynamic data;

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static String _turulKey(dynamic raw) => raw?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (data is! List) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(child: Text(l10n.tr('tailan_empty'))),
        ],
      );
    }

    final raw = (data as List<dynamic>)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (raw.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              l10n.tr('tailan_empty'),
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    String labelFor(String turul) {
      switch (turul) {
        case 'belen':
          return l10n.tr('tailan_pay_belen');
        case 'cart':
          return l10n.tr('tailan_pay_cart');
        case 'qpay':
          return l10n.tr('tailan_pay_qpay');
        case 'khariltsakh':
          return l10n.tr('tailan_pay_khariltsakh');
        case 'zeel':
          return l10n.tr('tailan_pay_zeel');
        case 'hunglult':
          return l10n.tr('tailan_pay_hunglult');
        default:
          return turul.isEmpty ? l10n.tr('tailan_pay_other') : turul;
      }
    }

    final paymentRows = <Map<String, dynamic>>[];
    Map<String, dynamic>? hunglultRow;
    for (final m in raw) {
      final k = _turulKey(m['_id']);
      if (k == 'hunglult') {
        hunglultRow = m;
      } else {
        paymentRows.add(m);
      }
    }
    paymentRows.sort(
      (a, b) => _asDouble(b['niitDun']).compareTo(_asDouble(a['niitDun'])),
    );

    double paymentTotal = 0;
    for (final m in paymentRows) {
      paymentTotal += _asDouble(m['niitDun']);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          l10n.tr('tailan_payment_by_method'),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < paymentRows.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, color: colorScheme.outlineVariant),
                ListTile(
                  title: Text(
                    labelFor(_turulKey(paymentRows[i]['_id'])),
                    style: textTheme.titleSmall,
                  ),
                  trailing: Text(
                    MntAmountFormatter.formatTugrikSpaced(
                      _asDouble(paymentRows[i]['niitDun']),
                    ),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (hunglultRow != null) ...[
                Divider(height: 1, color: colorScheme.outlineVariant),
                ListTile(
                  title: Text(
                    labelFor('hunglult'),
                    style: textTheme.titleSmall,
                  ),
                  trailing: Text(
                    MntAmountFormatter.formatTugrikSpaced(
                      _asDouble(hunglultRow['niitDun']),
                    ),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
              Divider(height: 1, thickness: 1, color: colorScheme.outline),
              ListTile(
                title: Text(
                  l10n.tr('tailan_total_received'),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                trailing: Text(
                  MntAmountFormatter.formatTugrikSpaced(paymentTotal),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
