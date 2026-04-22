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

/// Web parity: [BaraaniiTailan.js] — main grid + modal [OrlogoZarlagaDelegrengui] (`/baraagaarTailanAvya`).
class BaraaTailanTab extends StatefulWidget {
  const BaraaTailanTab({
    super.key,
    required this.range,
  });

  final DateTimeRange range;

  @override
  State<BaraaTailanTab> createState() => _BaraaTailanTabState();
}

class _BaraaTailanTabState extends State<BaraaTailanTab> {
  final TailanService _tailan = TailanService();
  final PosSettingsService _settings = PosSettingsService();

  Future<_BaraaTailanBundle>? _future;
  int _page = 1;
  static const _pageSize = 100;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleLoad();
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

  void _scheduleLoad() {
    final session = context.read<AuthModel>().posSession;
    if (session == null) {
      setState(() {
        _future = Future.value(_BaraaTailanBundle.fail('no_session'));
      });
      return;
    }
    setState(() {
      _future = _load(session);
    });
  }

  Future<_BaraaTailanBundle> _load(PosSession session) async {
    final salbaruud = await _settings.fetchSalbaruud(session.baiguullagiinId);
    final map = <String, String>{};
    for (final s in salbaruud) {
      final id = s['_id']?.toString();
      final ner = s['ner']?.toString();
      if (id != null && ner != null) map[id] = ner;
    }

    final body = _tailan.pagedQueryBody(
      baiguullagiinId: session.baiguullagiinId,
      salbariinId: session.salbariinId,
      ekhlekh: widget.range.start,
      duusakh: widget.range.end,
      searchKeys: const ['baraanuud.code', 'baraanuud.ner', 'baraanuud.barCode'],
      order: const {'etssiinUldegdel': -1},
      page: _page,
      pageSize: _pageSize,
    );

    final res = await _tailan.post(path: '/baraaMaterialiinTailanAvya', body: body);
    if (!res.ok) {
      return _BaraaTailanBundle.error(res.error ?? '—');
    }
    return _BaraaTailanBundle.ok(
      raw: res.data,
      salbarNerById: map,
      page: _page,
      pageSize: _pageSize,
    );
  }

  Future<void> _refresh() async {
    final session = context.read<AuthModel>().posSession;
    if (session == null) return;
    _scheduleLoad();
    await _future;
  }

  void _openDetail(
    BuildContext context,
    Map<String, dynamic> row,
    Map<String, String> salbarNerById,
  ) {
    final session = context.read<AuthModel>().posSession;
    if (session == null) return;
    final id = row['_id'];
    if (id is! Map) return;
    final code = id['code']?.toString();
    final salId = id['salbariinId']?.toString();
    final ner = id['ner']?.toString() ?? row['ner']?.toString() ?? '';
    final barCode =
        id['barCode']?.toString() ?? id['code']?.toString() ?? '';
    if (code == null || salId == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _OrlogoZarlagaDetailSheet(
        range: widget.range,
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: salId,
        baraaniiCode: code,
        salbariinNer: salbarNerById[salId] ?? salId,
        baraaNer: ner,
        barCode: barCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<_BaraaTailanBundle>(
      future: _future,
      builder: (context, snap) {
        if (_future == null ||
            (snap.connectionState == ConnectionState.waiting && !snap.hasData)) {
          return const Center(child: CircularProgressIndicator());
        }
        final bundle = snap.data;
        if (bundle == null || bundle.noSession) {
          return Center(
            child: Text(
              l10n.tr('toololt_no_session'),
              style: textTheme.bodyLarge?.copyWith(color: AppColors.error),
            ),
          );
        }
        if (bundle.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                bundle.error!,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: AppColors.error),
              ),
            ),
          );
        }

        final rows = bundle.rows;
        final totalRows = bundle.totalRows;
        final totalPages = totalRows <= 0
            ? 1
            : ((totalRows - 1) ~/ _pageSize) + 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: _BaraaTailanTable(
                            rows: rows,
                            salbarNerById: bundle.salbarNerById,
                            page: _page,
                            pageSize: _pageSize,
                            onTapCell: (r) =>
                                _openDetail(context, r, bundle.salbarNerById),
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
                              setState(() => _page -= 1);
                              _scheduleLoad();
                            },
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text('$_page / $totalPages'),
                    IconButton(
                      onPressed: _page >= totalPages
                          ? null
                          : () {
                              setState(() => _page += 1);
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
    );
  }
}

class _BaraaTailanBundle {
  _BaraaTailanBundle._({
    required this.ok,
    this.rows = const [],
    this.salbarNerById = const {},
    this.totalRows = 0,
    this.page = 1,
    this.pageSize = 100,
    this.error,
    this.noSession = false,
  });

  final bool ok;
  final List<Map<String, dynamic>> rows;
  final Map<String, String> salbarNerById;
  final int totalRows;
  final int page;
  final int pageSize;
  final String? error;
  final bool noSession;

  factory _BaraaTailanBundle.ok({
    required dynamic raw,
    required Map<String, String> salbarNerById,
    required int page,
    required int pageSize,
  }) {
    List<Map<String, dynamic>> rows = [];
    int total = 0;
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map) {
        final j = first['jagsaalt'];
        if (j is List) {
          rows = j.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        final nm = first['niitMur'];
        if (nm is List && nm.isNotEmpty && nm.first is Map) {
          final t = (nm.first as Map)['too'];
          if (t is num) total = t.toInt();
        }
      }
    }
    return _BaraaTailanBundle._(
      ok: true,
      rows: rows,
      salbarNerById: salbarNerById,
      totalRows: total > 0 ? total : rows.length,
      page: page,
      pageSize: pageSize,
    );
  }

  factory _BaraaTailanBundle.error(String message) =>
      _BaraaTailanBundle._(ok: false, error: message);

  factory _BaraaTailanBundle.fail(String code) => _BaraaTailanBundle._(
        ok: false,
        noSession: code == 'no_session',
        error: code == 'no_session' ? null : code,
      );
}

class _BaraaTailanTable extends StatelessWidget {
  const _BaraaTailanTable({
    required this.rows,
    required this.salbarNerById,
    required this.page,
    required this.pageSize,
    required this.onTapCell,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, String> salbarNerById;
  final int page;
  final int pageSize;
  final void Function(Map<String, dynamic> row) onTapCell;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    TextStyle? th() => textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurfaceVariant,
        );

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
          children: [
            _cellPad(Text('№', style: th()), w: 36),
            _cellPad(Text(l10n.tr('baraa_tailan_col_name'), style: th()), w: 160),
            _cellPad(Text(l10n.tr('baraa_tailan_col_code'), style: th()), w: 100),
            _cellPad(Text(l10n.tr('baraa_tailan_col_branch'), style: th()), w: 88),
            _cellPad(Text(l10n.tr('baraa_tailan_col_opening'), style: th()), w: 88),
            _cellPad(Text(l10n.tr('baraa_tailan_col_in'), style: th()), w: 72),
            _cellPad(Text(l10n.tr('baraa_tailan_col_out'), style: th()), w: 72),
            _cellPad(Text(l10n.tr('baraa_tailan_col_closing'), style: th()), w: 88),
            _cellPad(Text(l10n.tr('baraa_tailan_col_unit_cost'), style: th()), w: 88),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          _dataRow(
            context,
            index: (page - 1) * pageSize + i + 1,
            row: rows[i],
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
      ],
    );
  }

  TableRow _dataRow(
    BuildContext context, {
    required int index,
    required Map<String, dynamic> row,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    final id = row['_id'];
    Map<String, dynamic>? idMap;
    if (id is Map) idMap = Map<String, dynamic>.from(id);
    final code = idMap?['code']?.toString() ?? '';
    final salId = idMap?['salbariinId']?.toString();
    final ner = idMap?['ner']?.toString() ?? row['ner']?.toString() ?? '';
    final salNer =
        salId != null ? (salbarNerById[salId] ?? salId) : '';

    final ek = _toDouble(row['ekhniiUldegdel']);
    final or = _toDouble(row['orlogo']);
    final za = _toDouble(row['zarlaga']);
    final et = _toDouble(row['etssiinUldegdel']);
    final urtug = _pickUrtug(row['urtug']);

    return TableRow(
      children: [
        _cellPad(Text('$index', style: textTheme.bodySmall)),
        _cellPad(
          Text(ner, style: textTheme.bodySmall, maxLines: 2),
          w: 160,
        ),
        _cellPad(Text(code, style: textTheme.bodySmall)),
        _cellPad(Text(salNer, style: textTheme.bodySmall)),
        _cellPad(Text(_fmtQty(ek), style: textTheme.bodySmall)),
        _cellPad(
          InkWell(
            onTap: () => onTapCell(row),
            child: Text(
              _fmtQty(or),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          w: 72,
        ),
        _cellPad(
          InkWell(
            onTap: () => onTapCell(row),
            child: Text(
              _fmtQty(za),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          w: 72,
        ),
        _cellPad(Text(_fmtQty(et), style: textTheme.bodySmall)),
        _cellPad(
          Text(
            urtug != null ? MntAmountFormatter.formatTugrik(urtug) : '—',
            style: textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  static Widget _cellPad(Widget child, {double? w}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: w != null ? SizedBox(width: w, child: child) : child,
    );
  }

  static double? _pickUrtug(dynamic v) {
    final d = _toDouble(v);
    return d;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is List && v.isNotEmpty) return _toDouble(v.first);
    return double.tryParse(v.toString());
  }

  static String _fmtQty(double? v) {
    if (v == null) return '—';
    return v.toStringAsFixed(2);
  }
}

/// Bottom sheet: `POST /baraagaarTailanAvya` — Орлого зарлагын дэлгэрэнгүй.
class _OrlogoZarlagaDetailSheet extends StatefulWidget {
  const _OrlogoZarlagaDetailSheet({
    required this.range,
    required this.baiguullagiinId,
    required this.salbariinId,
    required this.baraaniiCode,
    required this.salbariinNer,
    required this.baraaNer,
    required this.barCode,
  });

  final DateTimeRange range;
  final String baiguullagiinId;
  final String salbariinId;
  final String baraaniiCode;
  final String salbariinNer;
  final String baraaNer;
  final String barCode;

  @override
  State<_OrlogoZarlagaDetailSheet> createState() =>
      _OrlogoZarlagaDetailSheetState();
}

class _OrlogoZarlagaDetailSheetState extends State<_OrlogoZarlagaDetailSheet> {
  final TailanService _tailan = TailanService();
  Future<TailanPostResult>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<TailanPostResult> _load() async {
    final body = <String, dynamic>{
      'baiguullagiinId': widget.baiguullagiinId,
      'ekhlekhOgnoo': TailanService.formatDateTime(widget.range.start),
      'duusakhOgnoo': TailanService.formatDateTime(widget.range.end),
      'salbariinId': widget.salbariinId,
      'baraaniiCode': widget.baraaniiCode,
      'khuudasniiDugaar': 1,
      'khuudasniiKhemjee': 500,
      'order': const {'createdAt': -1},
    };
    return _tailan.post(path: '/baraagaarTailanAvya', body: body);
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
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.tr('baraa_tailan_detail_branch')}: ${widget.salbariinNer}',
                      style: textTheme.bodyMedium,
                    ),
                    Text(
                      '${l10n.tr('baraa_tailan_detail_product')}: ${widget.baraaNer}',
                      style: textTheme.bodyMedium,
                    ),
                    Text(
                      '${l10n.tr('baraa_tailan_detail_barcode')}: ${widget.barCode}',
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
                    final list = _extractJagsaalt(r.data);
                    if (list.isEmpty) {
                      return Center(child: Text(l10n.tr('tailan_empty')));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                      itemCount: list.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _DetailHeaderRow(l10n: l10n);
                        }
                        return _DetailDataRow(
                          index: i,
                          doc: list[i - 1],
                          textTheme: textTheme,
                          colorScheme: colorScheme,
                        );
                      },
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

  static List<Map<String, dynamic>> _extractJagsaalt(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map && first['jagsaalt'] is List) {
        return (first['jagsaalt'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
    return [];
  }
}

class _DetailHeaderRow extends StatelessWidget {
  const _DetailHeaderRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _hcell('№', 28, t),
            _hcell(l10n.tr('baraa_tailan_d_col_date'), 132, t),
            _hcell(l10n.tr('baraa_tailan_d_col_receipt'), 88, t),
            _hcell(l10n.tr('baraa_tailan_d_col_type'), 88, t),
            _hcell(l10n.tr('baraa_tailan_d_col_staff'), 72, t),
            _hcell(l10n.tr('baraa_tailan_d_col_in_qty'), 56, t),
            _hcell(l10n.tr('baraa_tailan_d_col_in_price'), 72, t),
            _hcell(l10n.tr('baraa_tailan_d_col_out_qty'), 56, t),
            _hcell(l10n.tr('baraa_tailan_d_col_out_price'), 72, t),
            _hcell(l10n.tr('baraa_tailan_d_col_total'), 96, t),
          ],
        ),
      ),
    );
  }

  Widget _hcell(String s, double w, TextStyle? t) {
    return SizedBox(
      width: w,
      child: Text(s, style: t, maxLines: 2),
    );
  }
}

class _DetailDataRow extends StatelessWidget {
  const _DetailDataRow({
    required this.index,
    required this.doc,
    required this.textTheme,
    required this.colorScheme,
  });

  final int index;
  final Map<String, dynamic> doc;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final created = doc['createdAt'];
    DateTime? dt;
    if (created is String) {
      dt = DateTime.tryParse(created);
    } else if (created is Map && created['\$date'] != null) {
      dt = DateTime.tryParse(created['\$date'].toString());
    }
    final dateStr = dt != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal())
        : '';

    final guilgee = doc['guilgeeniiDugaar']?.toString() ?? '';
    final turul = _turulLabel(doc['turul']?.toString());
    final aj = doc['ajiltan'];
    final ajNer = aj is Map ? aj['ner']?.toString() ?? '' : '';

    final b = doc['baraanuud'];
    Map<String, dynamic>? bm;
    if (b is Map) bm = Map<String, dynamic>.from(b);
    final urs = doc['ursgaliinTurul']?.toString();
    final tur = doc['turul']?.toString() ?? '';

    final turL = tur.toLowerCase();
    final isOrlogo = urs == 'orlogo' || turL.contains('orlogo');
    final isZarlaga = urs == 'zarlaga' || turL.contains('zarlaga');

    final too = _toD(bm?['too']);
    final urtugUne = _toD(bm?['urtugUne']);
    final niitUne = _toD(bm?['niitUne']);
    final negjUne = _toD(bm?['negjUne']);

    double? inQty;
    double? inPrice;
    double? outQty;
    double? outPrice;
    double? lineTotal;

    if (isOrlogo) {
      inQty = too;
      inPrice = urtugUne ?? (too != null && niitUne != null && too != 0
          ? niitUne / too
          : null);
      lineTotal = (niitUne != null)
          ? niitUne
          : ((urtugUne ?? 0) * (too ?? 0));
    } else if (isZarlaga) {
      outQty = too;
      outPrice = negjUne ??
          (too != null && niitUne != null && too != 0 ? niitUne / too : null);
      lineTotal = niitUne;
    } else {
      lineTotal = niitUne ?? ((urtugUne ?? 0) * (too ?? 0));
    }

    final style = textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dcell('$index', 28, style),
            _dcell(dateStr, 132, style),
            _dcell(guilgee, 88, style),
            _dcell(turul, 88, style),
            _dcell(ajNer, 72, style),
            _dcell(inQty != null ? _fmtN(inQty) : '', 56, style),
            _dcell(inPrice != null ? MntAmountFormatter.formatTugrik(inPrice) : '', 72, style),
            _dcell(outQty != null ? _fmtN(outQty) : '', 56, style),
            _dcell(outPrice != null ? MntAmountFormatter.formatTugrik(outPrice) : '', 72, style),
            _dcell(
              lineTotal != null ? MntAmountFormatter.formatTugrik(lineTotal) : '',
              96,
              style?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  static double? _toD(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _fmtN(double v) {
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '') == ''
        ? '0'
        : v.toStringAsFixed(2);
  }

  static String _turulLabel(String? t) {
    if (t == null || t.isEmpty) return '';
    switch (t) {
      case 'ekhniiUldegdel':
        return 'Эхний үлдэгдэл';
      case 'khudulguun':
        return 'Хөдөлгөөн';
      case 'orlogo':
        return 'Орлого';
      case 'act':
        return 'Акт';
      case 'busadZarlaga':
        return 'Бусад зарлага';
      default:
        return t;
    }
  }

  Widget _dcell(String s, double w, TextStyle? style) {
    return SizedBox(
      width: w,
      child: Text(s, style: style, maxLines: 3),
    );
  }
}
