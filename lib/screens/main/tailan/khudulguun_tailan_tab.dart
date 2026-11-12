import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/auth_model.dart';
import '../../../services/tailan_service.dart';
import '../../../utils/mnt_amount_formatter.dart';

/// Хөдөлгөөний тайлан — салбар хоорондын барааны шилжүүлэг (вэбийн
/// `pages/khyanalt/tailan/KhudulguuniiTailan.js`-тэй ижил өгөгдөл).
/// Backend: `POST /khudulguuniiTailanAvya` → `{ barimtaar, baraagaar, niit }`.
/// Одоогийн салбараас гарсан ЭСВЭЛ орсон хөдөлгөөнийг харуулна.
class KhudulguunTailanTab extends StatefulWidget {
  const KhudulguunTailanTab({super.key, required this.range});

  final DateTimeRange range;

  @override
  State<KhudulguunTailanTab> createState() => _KhudulguunTailanTabState();
}

class _KhudulguunTailanTabState extends State<KhudulguunTailanTab> {
  final TailanService _tailan = TailanService();
  final TextEditingController _search = TextEditingController();
  Future<TailanPostResult>? _future;
  bool _baraagaar = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant KhudulguunTailanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range) {
      setState(() => _future = _load());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<TailanPostResult> _load() async {
    final session = context.read<AuthModel>().posSession;
    if (session == null) return TailanPostResult.fail('no_session');
    final start = DateTime(
        widget.range.start.year, widget.range.start.month, widget.range.start.day);
    final end = DateTime(widget.range.end.year, widget.range.end.month,
        widget.range.end.day, 23, 59, 59, 999);
    return _tailan.post(
      path: '/khudulguuniiTailanAvya',
      body: {
        'baiguullagiinId': session.baiguullagiinId,
        'salbariinId': session.salbariinId,
        'ekhlekhOgnoo': start.toUtc().toIso8601String(),
        'duusakhOgnoo': end.toUtc().toIso8601String(),
        if (_search.text.trim().isNotEmpty) 'khailt': _search.text.trim(),
      },
    );
  }

  static double _n(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static String _too(dynamic v) {
    final d = _n(v);
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => setState(() => _future = _load()),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Бараа хайх (код, нэр)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() => _future = _load());
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: true, label: Text('Бараагаар')),
                  ButtonSegment(value: false, label: Text('Баримтаар')),
                ],
                selected: {_baraagaar},
                onSelectionChanged: (s) => setState(() => _baraagaar = s.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<TailanPostResult>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final r = snap.data;
              if (r == null || !r.ok) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(r?.error ?? '—',
                        textAlign: TextAlign.center,
                        style: tt.bodyLarge?.copyWith(color: cs.error)),
                  ),
                );
              }
              final data = r.data is Map ? r.data as Map : const {};
              final rows = ((_baraagaar ? data['baraagaar'] : data['barimtaar'])
                          as List? ??
                      const [])
                  .whereType<Map>()
                  .toList();
              return RefreshIndicator(
                onRefresh: () async {
                  final f = _load();
                  setState(() => _future = f);
                  await f;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text('Энэ хугацаанд хөдөлгөөн алга',
                              style: tt.bodyLarge
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                      )
                    else
                      for (final m in rows)
                        _baraagaar ? _baraaMur(m, tt, cs) : _barimtMur(m, tt, cs),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chiglel(Map m, TextTheme tt, ColorScheme cs) => Row(
        children: [
          Flexible(
            child: Text('${m['garsanSalbariinNer'] ?? '-'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.arrow_forward_rounded,
                size: 14, color: cs.onSurfaceVariant),
          ),
          Flexible(
            child: Text('${m['orsonSalbariinNer'] ?? '-'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ],
      );

  Widget _baraaMur(Map m, TextTheme tt, ColorScheme cs) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text('${m['ner'] ?? '-'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ('${m['code'] ?? ''}'.isNotEmpty)
                Text('${m['code']}', style: tt.labelSmall),
              _chiglel(m, tt, cs),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_too(m['too'])} ш',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(MntAmountFormatter.formatTugrikSpaced(_n(m['dun'])),
                  style: tt.bodySmall),
            ],
          ),
        ),
      );

  Widget _barimtMur(Map m, TextTheme tt, ColorScheme cs) {
    final ognoo = DateTime.tryParse('${m['ognoo'] ?? ''}')?.toLocal();
    final ognooText = ognoo == null
        ? '-'
        : '${ognoo.year}-${ognoo.month.toString().padLeft(2, '0')}-${ognoo.day.toString().padLeft(2, '0')}';
    final baraanuud = (m['baraanuud'] as List? ?? const []).whereType<Map>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text('$ognooText · №${m['barimtiinDugaar'] ?? '-'}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chiglel(m, tt, cs),
            Text(
              '${m['baraaniiTuruul'] ?? 0} бараа · ${_too(m['niitToo'])} ш'
              '${'${m['ajiltan'] ?? ''}'.isNotEmpty ? ' · ${m['ajiltan']}' : ''}',
              style: tt.bodySmall,
            ),
          ],
        ),
        trailing: Text(MntAmountFormatter.formatTugrikSpaced(_n(m['niitDun'])),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        children: [
          for (final b in baraanuud)
            ListTile(
              dense: true,
              title: Text('${b['ner'] ?? '-'}'),
              subtitle: Text('${b['code'] ?? ''}'),
              trailing: Text(
                  '${_too(b['too'])} ш · ${MntAmountFormatter.formatTugrikSpaced(_n(b['dun']))}'),
            ),
          if ('${m['tailbar'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Тайлбар: ${m['tailbar']}', style: tt.bodySmall),
              ),
            ),
        ],
      ),
    );
  }
}
