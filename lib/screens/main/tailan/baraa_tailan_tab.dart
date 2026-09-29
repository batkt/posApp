import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/auth_model.dart';
import '../../../models/locale_model.dart';
import '../../../models/pos_session.dart';
import '../../../services/pos_settings_service.dart';
import '../../../services/tailan_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/mnt_amount_formatter.dart';

/// Барааны тайлан — вэбийн `pages/khyanalt/tailan/BaraaniiTailan.js`-тэй ижил:
/// `POST /baraaMaterialiinTailanAvya` (Бараагаар / Ангиллаар), хуудасны "Нийт"
/// мөр, Орлого/Зарлага дээр дарахад `POST /baraagaarTailanAvya` дэлгэрэнгүй
/// (`OrlogoZarlagaDelegrengui`).
class BaraaTailanTab extends StatefulWidget {
  const BaraaTailanTab({super.key, required this.range});

  final DateTimeRange range;

  @override
  State<BaraaTailanTab> createState() => _BaraaTailanTabState();
}

class _BaraaTailanTabState extends State<BaraaTailanTab> {
  final TailanService _tailan = TailanService();
  final PosSettingsService _settings = PosSettingsService();
  final TextEditingController _search = TextEditingController();
  Timer? _searchDebounce;

  Future<_BaraaTailanBundle>? _future;
  Map<String, String>? _salbarNerById;
  bool _angilalaar = false;
  int _page = 1;
  static const _pageSize = 100;

  /// Вэб `searchKeys`
  static const _searchKeys = [
    'baraanuud.code',
    'baraanuud.ner',
    'baraanuud.barCode'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleLoad();
    });
  }

  @override
  void didUpdateWidget(covariant BaraaTailanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range != widget.range) {
      _page = 1;
      _scheduleLoad();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _scheduleLoad() {
    final session = context.read<AuthModel>().posSession;
    setState(() {
      _future = session == null
          ? Future.value(_BaraaTailanBundle.fail('no_session'))
          : _load(session);
    });
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _page = 1;
      _scheduleLoad();
    });
  }

  Future<_BaraaTailanBundle> _load(PosSession session) async {
    if (_salbarNerById == null) {
      final salbaruud = await _settings.fetchSalbaruud(session.baiguullagiinId);
      final map = <String, String>{};
      for (final s in salbaruud) {
        final id = s['_id']?.toString();
        final ner = s['ner']?.toString();
        if (id != null && ner != null) map[id] = ner;
      }
      _salbarNerById = map;
    }

    final search = _angilalaar ? '' : _search.text.trim();
    // Вэб `useBaraaMaterialiinTailan` fetcher-ийн body
    final body = <String, dynamic>{
      'ekhlekhOgnoo':
          DateFormat('yyyy-MM-dd 00:00:00').format(widget.range.start),
      'duusakhOgnoo':
          DateFormat('yyyy-MM-dd 23:59:59').format(widget.range.end),
      'salbariinId': session.salbariinId,
      'baiguullagiinId': session.baiguullagiinId,
      'angilalaar': _angilalaar,
      'khuudasniiDugaar': _page,
      'khuudasniiKhemjee': _pageSize,
      'query': <String, dynamic>{
        r'$or': _searchKeys
            .map((k) => <String, dynamic>{
                  k: <String, dynamic>{
                    r'$regex': RegExp.escape(search),
                    r'$options': 'i'
                  },
                })
            .toList(),
      },
      'order': const {'createdAt': -1},
    };

    final res =
        await _tailan.post(path: '/baraaMaterialiinTailanAvya', body: body);
    if (!res.ok) return _BaraaTailanBundle.error(res.error ?? '—');
    return _BaraaTailanBundle.ok(
        raw: res.data, salbarNerById: _salbarNerById ?? const {});
  }

  Future<void> _refresh() async {
    _scheduleLoad();
    await _future;
  }

  void _openDetail(
      Map<String, dynamic> row, Map<String, String> salbarNerById) {
    final session = context.read<AuthModel>().posSession;
    if (session == null) return;
    final id = row['_id'];
    if (id is! Map) return;
    final code = id['code']?.toString();
    final salId = id['salbariinId']?.toString() ?? session.salbariinId;
    if (code == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _OrlogoZarlagaDetailSheet(
        range: widget.range,
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: salId,
        baraaniiCode: code,
        baraaniiBarCode: id['barCode']?.toString(),
        salbariinNer: salbarNerById[salId] ?? salId,
        baraaNer: _Fmt.firstStr(id['ner']) ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Бараагаар / Ангиллаар + хайлт (вэбийн Tabs + хайлтын талбар)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: false,
                      label: Text(l10n.tr('baraa_tailan_by_product'))),
                  ButtonSegment(
                      value: true,
                      label: Text(l10n.tr('baraa_tailan_by_category'))),
                ],
                selected: {_angilalaar},
                onSelectionChanged: (v) {
                  setState(() {
                    _angilalaar = v.first;
                    _page = 1;
                  });
                  _scheduleLoad();
                },
              ),
              if (!_angilalaar) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      hintText: l10n.tr('baraa_tailan_search_hint'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<_BaraaTailanBundle>(
            future: _future,
            builder: (context, snap) {
              if (_future == null ||
                  (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData)) {
                return const Center(child: CircularProgressIndicator());
              }
              final bundle = snap.data;
              if (bundle == null || bundle.noSession || bundle.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      bundle?.error ?? l10n.tr('toololt_no_session'),
                      textAlign: TextAlign.center,
                      style:
                          textTheme.bodyLarge?.copyWith(color: AppColors.error),
                    ),
                  ),
                );
              }

              final rows = bundle.rows;
              final totalPages = bundle.totalRows <= 0
                  ? 1
                  : ((bundle.totalRows - 1) ~/ _pageSize) + 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rows.isNotEmpty) _NiitKartuud(rows: rows),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: rows.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    l10n.tr('tailan_empty'),
                                    style: textTheme.bodyLarge?.copyWith(
                                        color: colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: _BaraaTailanTable(
                                  rows: rows,
                                  angilalaar: _angilalaar,
                                  salbarNerById: bundle.salbarNerById,
                                  startIndex: (_page - 1) * _pageSize,
                                  onTapMovement: (r) =>
                                      _openDetail(r, bundle.salbarNerById),
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _page <= 1
                                ? null
                                : () {
                                    _page -= 1;
                                    _scheduleLoad();
                                  },
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Text('$_page / $totalPages · ${bundle.totalRows}'),
                          IconButton(
                            onPressed: _page >= totalPages
                                ? null
                                : () {
                                    _page += 1;
                                    _scheduleLoad();
                                  },
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BaraaTailanBundle {
  _BaraaTailanBundle._({
    this.rows = const [],
    this.salbarNerById = const {},
    this.totalRows = 0,
    this.error,
    this.noSession = false,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, String> salbarNerById;
  final int totalRows;
  final String? error;
  final bool noSession;

  factory _BaraaTailanBundle.ok({
    required dynamic raw,
    required Map<String, String> salbarNerById,
  }) {
    var rows = <Map<String, dynamic>>[];
    var total = 0;
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      final first = raw.first as Map;
      final j = first['jagsaalt'];
      if (j is List) {
        rows = j
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      final nm = first['niitMur'];
      if (nm is List && nm.isNotEmpty && nm.first is Map) {
        final t = (nm.first as Map)['too'];
        if (t is num) total = t.toInt();
      }
    }
    return _BaraaTailanBundle._(
      rows: rows,
      salbarNerById: salbarNerById,
      totalRows: total > 0 ? total : rows.length,
    );
  }

  factory _BaraaTailanBundle.error(String message) =>
      _BaraaTailanBundle._(error: message);

  factory _BaraaTailanBundle.fail(String code) => _BaraaTailanBundle._(
        noSession: code == 'no_session',
        error: code == 'no_session' ? null : code,
      );
}

/// Тоо, мөнгөн дүнгийн хэлбэржүүлэлт (вэб `formatNumber(v, 2)`).
abstract final class _Fmt {
  static final _qty = NumberFormat('#,##0.##');

  static double d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is List) return v.isEmpty ? 0 : d(v.first);
    return double.tryParse(v.toString()) ?? 0;
  }

  static String? firstStr(dynamic v) {
    if (v == null) return null;
    if (v is List) return v.isEmpty ? null : v.first?.toString();
    return v.toString();
  }

  static String qty(dynamic v) => _qty.format(d(v));
  static String mnt(dynamic v) => MntAmountFormatter.formatTugrik(d(v));
}

/// Хуудасны нийт — вэбийн хүснэгтийн "Нийт" (HulDun) мөртэй ижил дүн, дээр нь картаар.
class _NiitKartuud extends StatelessWidget {
  const _NiitKartuud({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    double sum(String k) => rows.fold(0, (a, r) => a + _Fmt.d(r[k]));
    final items = [
      (l10n.tr('baraa_tailan_col_opening'), sum('ekhniiUldegdel'), null),
      (l10n.tr('baraa_tailan_col_in'), sum('orlogo'), AppColors.success),
      (l10n.tr('baraa_tailan_col_out'), sum('zarlaga'), AppColors.error),
      (l10n.tr('baraa_tailan_col_closing'), sum('etssiinUldegdel'), null),
    ];
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items[i].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _Fmt.qty(items[i].$2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: items[i].$3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Вэбийн хүснэгтийн баганууд:
///   Бараагаар: № · Барааны нэр · Дотоод код · Бар код · Салбар · Худалдах үнэ ·
///              Эх/үлдэгдэл · Орлого · Зарлага · Эц/үлдэгдэл · Нэгж өртөг
///   Ангиллаар: Ангилал · Эх/үлдэгдэл · Орлого · Зарлага · Эц/үлдэгдэл
/// + доод "Нийт" мөр.
class _BaraaTailanTable extends StatelessWidget {
  const _BaraaTailanTable({
    required this.rows,
    required this.angilalaar,
    required this.salbarNerById,
    required this.startIndex,
    required this.onTapMovement,
  });

  final List<Map<String, dynamic>> rows;
  final bool angilalaar;
  final Map<String, String> salbarNerById;
  final int startIndex;
  final void Function(Map<String, dynamic> row) onTapMovement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final th = textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurfaceVariant,
    );
    final td = textTheme.bodySmall;
    final tdBold = td?.copyWith(fontWeight: FontWeight.w700);
    final link = td?.copyWith(
        color: colorScheme.primary, decoration: TextDecoration.underline);

    double sum(String k) => rows.fold(0, (a, r) => a + _Fmt.d(r[k]));

    Widget c(Widget child, {double? w, bool right = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: SizedBox(
            width: w,
            child: Align(
                alignment: right ? Alignment.centerRight : Alignment.centerLeft,
                child: child),
          ),
        );
    Widget tap(Map<String, dynamic> r, String text) =>
        InkWell(onTap: () => onTapMovement(r), child: Text(text, style: link));

    final List<TableRow> tableRows;
    if (angilalaar) {
      tableRows = [
        TableRow(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
          children: [
            c(Text(l10n.tr('baraa_tailan_col_category'), style: th), w: 180),
            c(Text(l10n.tr('baraa_tailan_col_opening'), style: th),
                w: 90, right: true),
            c(Text(l10n.tr('baraa_tailan_col_in'), style: th),
                w: 80, right: true),
            c(Text(l10n.tr('baraa_tailan_col_out'), style: th),
                w: 80, right: true),
            c(Text(l10n.tr('baraa_tailan_col_closing'), style: th),
                w: 90, right: true),
          ],
        ),
        for (final r in rows)
          TableRow(children: [
            c(
                Text(
                    _Fmt.firstStr(r['_id']) ??
                        l10n.tr('baraa_tailan_uncategorized'),
                    style: td,
                    maxLines: 2),
                w: 180),
            c(Text(_Fmt.qty(r['ekhniiUldegdel']), style: td), right: true),
            c(Text(_Fmt.qty(r['orlogo']), style: td), right: true),
            c(Text(_Fmt.qty(r['zarlaga']), style: td), right: true),
            c(Text(_Fmt.qty(r['etssiinUldegdel']), style: td), right: true),
          ]),
        TableRow(
          decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
          children: [
            c(Text(l10n.tr('baraa_tailan_total'), style: tdBold)),
            c(Text(_Fmt.qty(sum('ekhniiUldegdel')), style: tdBold),
                right: true),
            c(Text(_Fmt.qty(sum('orlogo')), style: tdBold), right: true),
            c(Text(_Fmt.qty(sum('zarlaga')), style: tdBold), right: true),
            c(Text(_Fmt.qty(sum('etssiinUldegdel')), style: tdBold),
                right: true),
          ],
        ),
      ];
    } else {
      tableRows = [
        TableRow(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
          children: [
            c(Text('№', style: th), w: 30),
            c(Text(l10n.tr('baraa_tailan_col_name'), style: th), w: 170),
            c(Text(l10n.tr('baraa_tailan_col_code'), style: th), w: 90),
            c(Text(l10n.tr('baraa_tailan_col_barcode'), style: th), w: 110),
            c(Text(l10n.tr('baraa_tailan_col_branch'), style: th), w: 90),
            c(Text(l10n.tr('baraa_tailan_col_price'), style: th),
                w: 90, right: true),
            c(Text(l10n.tr('baraa_tailan_col_opening'), style: th),
                w: 80, right: true),
            c(Text(l10n.tr('baraa_tailan_col_in'), style: th),
                w: 70, right: true),
            c(Text(l10n.tr('baraa_tailan_col_out'), style: th),
                w: 70, right: true),
            c(Text(l10n.tr('baraa_tailan_col_closing'), style: th),
                w: 80, right: true),
            c(Text(l10n.tr('baraa_tailan_col_unit_cost'), style: th),
                w: 90, right: true),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          () {
            final r = rows[i];
            final id = r['_id'] is Map
                ? Map<String, dynamic>.from(r['_id'] as Map)
                : <String, dynamic>{};
            final salId = id['salbariinId']?.toString();
            return TableRow(children: [
              c(Text('${startIndex + i + 1}', style: td)),
              c(Text(_Fmt.firstStr(id['ner']) ?? '', style: td, maxLines: 2),
                  w: 170),
              c(Text(_Fmt.firstStr(id['code']) ?? '', style: td)),
              c(Text(_Fmt.firstStr(id['barCode']) ?? '', style: td)),
              c(Text(salId != null ? (salbarNerById[salId] ?? '') : '',
                  style: td, maxLines: 1)),
              c(Text(_Fmt.mnt(r['une']), style: td), right: true),
              c(Text(_Fmt.qty(r['ekhniiUldegdel']), style: td), right: true),
              c(tap(r, _Fmt.qty(r['orlogo'])), right: true),
              c(tap(r, _Fmt.qty(r['zarlaga'])), right: true),
              c(Text(_Fmt.qty(r['etssiinUldegdel']), style: td), right: true),
              c(Text(_Fmt.mnt(r['urtug']), style: td), right: true),
            ]);
          }(),
        TableRow(
          decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
          children: [
            c(const SizedBox()),
            c(Text(l10n.tr('baraa_tailan_total'), style: tdBold)),
            c(const SizedBox()),
            c(const SizedBox()),
            c(const SizedBox()),
            c(const SizedBox()),
            c(Text(_Fmt.qty(sum('ekhniiUldegdel')), style: tdBold),
                right: true),
            c(Text(_Fmt.qty(sum('orlogo')), style: tdBold), right: true),
            c(Text(_Fmt.qty(sum('zarlaga')), style: tdBold), right: true),
            c(Text(_Fmt.qty(sum('etssiinUldegdel')), style: tdBold),
                right: true),
            c(const SizedBox()),
          ],
        ),
      ];
    }

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      children: tableRows,
    );
  }
}

/// Орлого/Зарлагын дэлгэрэнгүй — вэбийн `OrlogoZarlagaDelegrengui` (`/baraagaarTailanAvya`).
class _OrlogoZarlagaDetailSheet extends StatefulWidget {
  const _OrlogoZarlagaDetailSheet({
    required this.range,
    required this.baiguullagiinId,
    required this.salbariinId,
    required this.baraaniiCode,
    required this.baraaniiBarCode,
    required this.salbariinNer,
    required this.baraaNer,
  });

  final DateTimeRange range;
  final String baiguullagiinId;
  final String salbariinId;
  final String baraaniiCode;
  final String? baraaniiBarCode;
  final String salbariinNer;
  final String baraaNer;

  @override
  State<_OrlogoZarlagaDetailSheet> createState() =>
      _OrlogoZarlagaDetailSheetState();
}

class _OrlogoZarlagaDetailSheetState extends State<_OrlogoZarlagaDetailSheet> {
  final TailanService _tailan = TailanService();
  late final Future<TailanPostResult> _future;

  @override
  void initState() {
    super.initState();
    // Вэб `usebaraagaarAvsanTailan` fetcher-ийн body
    _future =
        _tailan.post(path: '/baraagaarTailanAvya', body: <String, dynamic>{
      'ekhlekhOgnoo':
          DateFormat('yyyy-MM-dd 00:00:00').format(widget.range.start),
      'duusakhOgnoo':
          DateFormat('yyyy-MM-dd 23:59:59').format(widget.range.end),
      'salbariinId': widget.salbariinId,
      'baraaniiCode': widget.baraaniiCode,
      if (widget.baraaniiBarCode != null)
        'baraaniiBarCode': widget.baraaniiBarCode,
      'baiguullagiinId': widget.baiguullagiinId,
      'khuudasniiDugaar': 1,
      'khuudasniiKhemjee': 500,
      'order': const {'createdAt': -1},
    });
  }

  static String _turulLabel(String? t) {
    switch (t) {
      case 'ekhniiUldegdel':
        return 'Эхний үлдэгдэл';
      case 'khudulguun':
        return 'Хөдөлгөөн';
      case 'khuselt':
        return 'Хүсэлт';
      case 'khurvuulelt':
        return 'Хөрвүүлэлт';
      case 'orlogo':
        return 'Орлого';
      case 'zakhialga':
        return 'Захиалга';
      case 'act':
        return 'Акт';
      case 'busadZarlaga':
        return 'Бусад зарлага';
      default:
        return t ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.tr('baraa_tailan_detail_title'),
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                        '${l10n.tr('baraa_tailan_detail_branch')}: ${widget.salbariinNer}',
                        style: textTheme.bodyMedium),
                    Text(
                        '${l10n.tr('baraa_tailan_detail_product')}: ${widget.baraaNer}',
                        style: textTheme.bodyMedium),
                    Text(
                      '${l10n.tr('baraa_tailan_detail_barcode')}: ${widget.baraaniiBarCode ?? widget.baraaniiCode}',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
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
                      return Center(child: Text(r?.error ?? '—'));
                    }
                    final list = <Map<String, dynamic>>[];
                    final raw = r.data;
                    if (raw is List && raw.isNotEmpty && raw.first is Map) {
                      final j = (raw.first as Map)['jagsaalt'];
                      if (j is List) {
                        list.addAll(j
                            .whereType<Map>()
                            .map((e) => Map<String, dynamic>.from(e)));
                      }
                    }
                    if (list.isEmpty) {
                      return Center(child: Text(l10n.tr('tailan_empty')));
                    }
                    return SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _detailTable(context, list, l10n),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.tr('baraa_tailan_detail_close')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailTable(BuildContext context, List<Map<String, dynamic>> list,
      AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final th = textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant);
    final td = textTheme.bodySmall;
    final tdBold = td?.copyWith(fontWeight: FontWeight.w700);
    final dim = td?.copyWith(color: colorScheme.onSurfaceVariant);

    Widget c(Widget child, {double? w, bool right = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: SizedBox(
            width: w,
            child: Align(
                alignment: right ? Alignment.centerRight : Alignment.centerLeft,
                child: child),
          ),
        );

    var niitOrlogo = 0.0;
    var niitZarlaga = 0.0;
    final dataRows = <TableRow>[];
    for (var i = 0; i < list.length; i++) {
      final doc = list[i];
      final created = doc['createdAt'];
      final dt = created is String
          ? DateTime.tryParse(created)
          : (created is Map ? DateTime.tryParse('${created[r'$date']}') : null);
      final turul = doc['turul']?.toString() ?? '';
      final urs = doc['ursgaliinTurul']?.toString();
      final b = doc['baraanuud'] is Map
          ? Map<String, dynamic>.from(doc['baraanuud'] as Map)
          : <String, dynamic>{};
      final too = _Fmt.d(b['too']);
      final ekhnii =
          RegExp('эхний|uldegdel', caseSensitive: false).hasMatch(turul);
      // Вэбийн дүрэм: Орлого — ursgaliinTurul "orlogo" эсвэл turul-д "orlogo";
      // Зарлага — ursgaliinTurul "zarlaga" эсвэл turul-д "Zarlaga"
      final isOrlogo = urs == 'orlogo' ||
          RegExp('orlogo', caseSensitive: false).hasMatch(turul);
      final isZarlaga = urs == 'zarlaga' || turul.contains('Zarlaga');
      final lineTotal =
          isZarlaga ? _Fmt.d(b['niitUne']) : _Fmt.d(b['urtugUne']) * too;
      // Эхний үлдэгдэл нь хугацааны орлого биш — нийтэд оруулахгүй (вэбтэй ижил)
      if (isOrlogo && !ekhnii) niitOrlogo += too;
      if (isZarlaga) niitZarlaga += too;
      final aj = doc['ajiltan'];

      dataRows.add(TableRow(children: [
        c(Text('${i + 1}', style: td)),
        c(Text(
            dt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal())
                : '',
            style: td)),
        c(Text(doc['guilgeeniiDugaar']?.toString() ?? '', style: td)),
        c(Text(_turulLabel(turul), style: td)),
        c(Text(aj is Map ? (aj['ner']?.toString() ?? '') : '', style: td)),
        c(
            Text(isOrlogo && too != 0 ? _Fmt.qty(too) : '',
                style: ekhnii ? dim : td),
            right: true),
        c(Text(isOrlogo ? _Fmt.mnt(b['urtugUne']) : '', style: td),
            right: true),
        c(Text(isZarlaga && too != 0 ? _Fmt.qty(too) : '', style: td),
            right: true),
        c(
          Text(
            isZarlaga
                ? _Fmt.mnt(
                    b['negjUne'] ?? (too != 0 ? _Fmt.d(b['niitUne']) / too : 0))
                : '',
            style: td,
          ),
          right: true,
        ),
        c(Text(_Fmt.mnt(lineTotal), style: tdBold), right: true),
      ]));
    }

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
          children: [
            c(Text('№', style: th)),
            c(Text(l10n.tr('baraa_tailan_d_col_date'), style: th)),
            c(Text(l10n.tr('baraa_tailan_d_col_receipt'), style: th)),
            c(Text(l10n.tr('baraa_tailan_d_col_type'), style: th)),
            c(Text(l10n.tr('baraa_tailan_d_col_staff'), style: th)),
            c(Text(l10n.tr('baraa_tailan_d_col_in_qty'), style: th),
                right: true),
            c(Text(l10n.tr('baraa_tailan_d_col_in_price'), style: th),
                right: true),
            c(Text(l10n.tr('baraa_tailan_d_col_out_qty'), style: th),
                right: true),
            c(Text(l10n.tr('baraa_tailan_d_col_out_price'), style: th),
                right: true),
            c(Text(l10n.tr('baraa_tailan_d_col_total'), style: th),
                right: true),
          ],
        ),
        ...dataRows,
        TableRow(
          decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
          children: [
            c(const SizedBox()),
            c(Text(l10n.tr('baraa_tailan_total'), style: tdBold)),
            c(const SizedBox()),
            c(const SizedBox()),
            c(const SizedBox()),
            c(Text(_Fmt.qty(niitOrlogo), style: tdBold), right: true),
            c(const SizedBox()),
            c(Text(_Fmt.qty(niitZarlaga), style: tdBold), right: true),
            c(const SizedBox()),
            c(const SizedBox()),
          ],
        ),
      ],
    );
  }
}
