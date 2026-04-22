import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../services/tailan_service.dart';
import 'tailan/baraa_tailan_tab.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';

/// Web parity: `/khyanalt/tailan/*` — tabbed reports matching Next.js tailan hooks.
class TailanScreen extends StatefulWidget {
  const TailanScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<TailanScreen> createState() => _TailanScreenState();
}

class _TailanScreenState extends State<TailanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TailanService _tailan = TailanService();

  late DateTimeRange _range;

  static const _tabKeys = <String>[
    'tailan_tab_summary',
    'tailan_tab_baraa',
    'tailan_tab_salesperson',
    'tailan_tab_sales',
    'tailan_tab_refund',
    'tailan_tab_receivable',
    'tailan_tab_payable',
    'tailan_tab_promo_summary',
    'tailan_tab_promo_detail',
    'tailan_tab_purchase',
    'tailan_tab_other_expense',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabKeys.length, vsync: this);
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
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
  }

  Future<TailanPostResult> _loadTab(int tabIndex) async {
    final session = context.read<AuthModel>().posSession;
    if (session == null) {
      return TailanPostResult.fail('no_session');
    }
    final bid = session.baiguullagiinId;
    final sid = session.salbariinId;
    final e = _range.start;
    final d = _range.end;

    switch (tabIndex) {
      case 0:
        return _tailan.borluulaltToim(
          baiguullagiinId: bid,
          salbariinId: sid,
          ekhlekh: e,
          duusakh: d,
          nariivchlal: 'month',
        );
      case 2:
        return _tailan.post(
          path: '/delgerenguiTailanAvya',
          body: _tailan.pagedQueryBody(
            baiguullagiinId: bid,
            salbariinId: sid,
            ekhlekh: e,
            duusakh: d,
            searchKeys: const [
              'baraanuud.baraa.code',
              'baraanuud.baraa.ner',
              'baraanuud.baraa.barCode',
            ],
          ),
        );
      case 3:
        return _tailan.post(
          path: '/borluulaltiinTailanAvya',
          body: _tailan.pagedQueryBody(
            baiguullagiinId: bid,
            salbariinId: sid,
            ekhlekh: e,
            duusakh: d,
            salbariinIdForIn: true,
            searchKeys: const [
              'baraanuud.baraa.angilal',
              'baraanuud.baraa.code',
            ],
          ),
        );
      case 4:
        return _tailan.post(
          path: '/butsaaltiinTailanAvya',
          body: _tailan.pagedQueryBody(
            baiguullagiinId: bid,
            salbariinId: sid,
            ekhlekh: e,
            duusakh: d,
            searchKeys: const [
              'baraanuud.baraa.code',
              'baraanuud.baraa.ner',
              'baraanuud.baraa.barCode',
            ],
          ),
        );
      case 5:
        return _tailan.post(
          path: '/avlagaTovchooTailanAvya',
          body: _tailan.avlagaUglugBody(
            baiguullagiinId: bid,
            salbariinId: sid,
            ekhlekh: e,
            duusakh: d,
          ),
        );
      case 6:
        return _tailan.post(
          path: '/uglugTovchooTailanAvya',
          body: _tailan.avlagaUglugBody(
            baiguullagiinId: bid,
            salbariinId: sid,
            ekhlekh: e,
            duusakh: d,
          ),
        );
      case 7:
        return _tailan.post(
          path: '/uramshuulliinTovchooTailanAvya',
          body: _tailan.uramshuulalTovchooBody(
            baiguullagiinId: bid,
            salbariinId: sid,
            ekhlekh: e,
            duusakh: d,
          ),
        );
      case 8:
        return _tailan.post(
          path: '/uramshuulliinDelgerenguiTailanAvya',
          body: _tailan.uramshuulalDelgerenguiBody(
            baiguullagiinId: bid,
            salbariinId: sid,
            ekhlekh: e,
            duusakh: d,
          ),
        );
      case 9:
        return _tailan.post(
          path: '/khariltsagchaarKHudaldanAvalt',
          body: _tailan.hudaldanAvaltTailanBody(
            baiguullagiinId: bid,
            salbariinId: sid,
            ekhlekh: e,
            duusakh: d,
          ),
        );
      case 10:
        return _tailan.post(
          path: '/zarlagaAktBaraaniiTailan',
          body: <String, dynamic>{
            'ekhlekhOgnoo': TailanService.formatDateTime(e),
            'duusakhOgnoo': TailanService.formatDateTime(d),
            'baiguullagiinId': bid,
            'salbariinId': [sid],
            'turul': 'busadZarlaga',
          },
        );
      default:
        return TailanPostResult.fail('unknown');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final df = DateFormat.yMMMd();

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.tr('tailan_menu')),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  for (final k in _tabKeys) Tab(text: l10n.tr(k)),
                ],
              ),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.showAppBar)
            Material(
              color: colorScheme.surfaceContainerHighest,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: [
                  for (final k in _tabKeys) Tab(text: l10n.tr(k)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(
                      '${df.format(_range.start)} – ${df.format(_range.end)}',
                      style: textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (var i = 0; i < _tabKeys.length; i++)
                  i == 1
                      ? BaraaTailanTab(
                          key: ValueKey<Object>(
                            'tailan_baraa_${_range.start}_${_range.end}',
                          ),
                          range: _range,
                        )
                      : _TailanTabBody(
                          key: ValueKey<Object>(
                            'tailan_$i${_range.start}_${_range.end}',
                          ),
                          load: () => _loadTab(i),
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TailanTabBody extends StatefulWidget {
  const _TailanTabBody({super.key, required this.load});

  final Future<TailanPostResult> Function() load;

  @override
  State<_TailanTabBody> createState() => _TailanTabBodyState();
}

class _TailanTabBodyState extends State<_TailanTabBody> {
  Future<TailanPostResult>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(covariant _TailanTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) {
      _future = widget.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<TailanPostResult>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
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
                style: textTheme.bodyLarge?.copyWith(color: AppColors.error),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = widget.load());
            await _future;
          },
          child: _TailanDataView(data: r.data),
        );
      },
    );
  }
}

class _TailanDataView extends StatelessWidget {
  const _TailanDataView({required this.data});

  final dynamic data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (data == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('—')),
        ],
      );
    }

    if (data is Map && data['labels'] != null && data['datasets'] != null) {
      final m = data as Map;
      final labels = m['labels'] as List?;
      final datasets = m['datasets'] as List?;
      if (labels != null && datasets != null && datasets.isNotEmpty) {
        final bor = datasets.isNotEmpty ? (datasets[0]['data'] as List?) : null;
        final ash =
            datasets.length > 1 ? (datasets[1]['data'] as List?) : null;
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: labels.length,
          itemBuilder: (_, i) {
            final label = '${labels[i]}';
            final b = bor != null && i < bor.length ? bor[i] : '';
            final a = ash != null && i < ash.length ? ash[i] : '';
            final ds0 = datasets.isNotEmpty ? datasets[0] as Map? : null;
            final ds1 =
                datasets.length > 1 ? datasets[1] as Map? : null;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(label, style: textTheme.titleSmall),
                subtitle: Text(
                  '${ds0?['label'] ?? 'Борлуулалт'}: $b\n'
                  '${datasets.length > 1 ? (ds1?['label'] ?? 'Ашиг') : ''}: $a',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          },
        );
      }
    }

    List<dynamic>? rows;
    if (data is List) {
      rows = data as List<dynamic>;
    } else if (data is Map && data['jagsaalt'] is List) {
      rows = data['jagsaalt'] as List<dynamic>;
    }

    if (rows != null) {
      final list = rows;
      if (list.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  AppLocalizations.of(context).tr('tailan_empty'),
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = list[i];
          return _TailanJsonCard(item: item);
        },
      );
    }

    if (data is Map) {
      final m = Map<String, dynamic>.from(data as Map);
      m.remove('jagsaalt');
      if (m.isEmpty) {
        return Center(
          child: Text(
            AppLocalizations.of(context).tr('tailan_empty'),
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: m.entries.map((e) {
          return ListTile(
            title: Text(
              e.key,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              tailanFmt(e.value),
              style: textTheme.bodyMedium,
            ),
          );
        }).toList(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(tailanFmt(data)),
    );
  }
}

String tailanFmt(dynamic v) {
  if (v == null) return '—';
  if (v is num) {
    if (v.abs() >= 1000 || v != v.roundToDouble()) {
      return MntAmountFormatter.formatTugrik(v.toDouble());
    }
    return v.toString();
  }
  if (v is Map || v is List) return v.toString();
  return v.toString();
}

class _TailanJsonCard extends StatelessWidget {
  const _TailanJsonCard({required this.item});

  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (item is! Map) {
      return Card(
        child: ListTile(
          title: Text(tailanFmt(item)),
        ),
      );
    }
    final m = Map<String, dynamic>.from(item as Map);
    final preview = m.entries
        .take(4)
        .map((e) => '${e.key}: ${tailanFmt(e.value)}')
        .join('\n');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        title: Text(
          m['_id']?.toString() ?? m['ner']?.toString() ?? 'Мөр',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          preview,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: m.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          e.key,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          tailanFmt(e.value),
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
