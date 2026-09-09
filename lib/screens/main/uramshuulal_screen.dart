import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../services/api_service.dart';
import '../../services/tailan_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_date_range_filter_button.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import '../../services/uramshuulal_service.dart';
import '../../utils/app_snackbar.dart';

/// Screen for managing & viewing Promotions (Урамшуулал) and Promotion Reports.
/// Урамшууллын ДЭЛГЭРЭНГҮЙ тайлангийн нэг мөр
/// (`POST /uramshuulliinDelgerenguiTailanAvya`).
///
/// Өмнө нь нэгтгэсэн `/uramshuulliinTovchooTailanAvya`-г уншдаг байсан ч
/// тэр нь баримтын дугаар, огноог ОГТ буцаадаггүй бөгөөд дүн нь өртөг
/// (`too × urtugUne`) байсан тул өртөггүй бараа "0.00" харагддаг байв.
class UramshuulalReportRow {
  const UramshuulalReportRow({
    required this.ner,
    required this.code,
    required this.too,
    required this.saleTotal,
    required this.costTotal,
    required this.unitLabel,
    this.barimtiinDugaar,
    this.ognoo,
    this.uramshuulal,
  });

  final String ner;
  final String code;
  final double too;
  final double saleTotal;
  final double costTotal;
  final String unitLabel;
  final String? barimtiinDugaar;
  final DateTime? ognoo;
  final String? uramshuulal;

  /// Мөрөнд харуулах дүн — ХУДАЛДАХ үнэ нь тэргүүн эрэмбэтэй.
  ///
  /// Хуучин гүйлгээнд `undsenZarakhUne` хадгалагдаагүй байж болох тул
  /// өртгөөр нөхнө; хоёулаа 0 бол [hasNoPrice] үнэн болно.
  double get amount => saleTotal > 0 ? saleTotal : costTotal;

  bool get hasNoPrice => saleTotal <= 0 && costTotal <= 0;

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? 0;
  }

  /// Бэлгийн мөрийн `too` нь хайрцагтай бараанд ХАЙРЦАГ, жингийнд КГ.
  static String _unitLabelFor(Map<String, dynamic> j) {
    final kn = j['khemjikhNegj']?.toString().trim().toLowerCase() ?? '';
    final neg = _num(j['negKhairtsaganDahiShirhegiinToo']);
    final boxFlag = j['shirkheglekhEsekh'];
    final isBox = boxFlag == true ||
        (boxFlag == null && (neg >= 2 || kn.contains('хайрцаг')));
    if (isBox) return 'хайрцаг';
    const weight = {'кг', 'kg', 'гр', 'грамм', 'g', 'gram'};
    if (weight.contains(kn)) return kn.startsWith('к') || kn == 'kg' ? 'кг' : 'гр';
    return 'ширхэг';
  }

  factory UramshuulalReportRow.fromJson(Map<String, dynamic> j) {
    return UramshuulalReportRow(
      ner: j['ner']?.toString() ?? j['_id']?['ner']?.toString() ?? 'Бараа',
      code: j['code']?.toString() ?? j['_id']?['code']?.toString() ?? '',
      too: _num(j['too'] ?? j['niitToo']),
      saleTotal: _num(j['niitZarakhUne']) > 0
          ? _num(j['niitZarakhUne'])
          : _num(j['undsenZarakhUne']) * _num(j['too'] ?? j['niitToo']),
      costTotal: _num(j['niitUrtug']),
      unitLabel: _unitLabelFor(j),
      barimtiinDugaar: j['barimtiinDugaar']?.toString(),
      ognoo: DateTime.tryParse(j['ognoo']?.toString() ?? ''),
      uramshuulal: j['uramshuulal'] is List
          ? (j['uramshuulal'] as List).whereType<String>().join(', ')
          : j['uramshuulal']?.toString(),
    );
  }
}

class UramshuulalScreen extends StatefulWidget {
  const UramshuulalScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<UramshuulalScreen> createState() => _UramshuulalScreenState();
}

class _UramshuulalScreenState extends State<UramshuulalScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Tab 1 state: Promotions list
  bool _loadingPromos = false;
  String? _promosError;
  List<Map<String, dynamic>> _promotions = [];

  // Tab 2 state: Promotion report
  bool _loadingReport = false;
  String? _reportError;
  /// Анхдагч муж нь ЭНЭ САР — 7 хоногийн муж нь урамшууллын тайланд хэт
  /// богино тул ихэвчлэн хоосон гардаг байв.
  DateTimeRange _range = _currentMonthRange();

  static DateTimeRange _currentMonthRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
  }

  List<UramshuulalReportRow> _reportItems = [];
  double _totalReportDiscount = 0.0;
  double _totalReportCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchPromotions();
      _fetchReport();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPromotions() async {
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) return;

    setState(() {
      _loadingPromos = true;
      _promosError = null;
    });

    try {
      final res = await posApiService.get<Map<String, dynamic>>(
        '/uramshuulal',
        queryParams: {
          'query': jsonEncode({
            'baiguullagiinId': pos.baiguullagiinId,
          }),
          'khuudasniiKhemjee': '100',
        },
        parser: (d) => d as Map<String, dynamic>,
      );

      if (!mounted) return;

      if (res.success && res.data != null) {
        final raw = res.data!['jagsaalt'] as List<dynamic>? ?? [];
        final list = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() {
          _promotions = list;
          _loadingPromos = false;
        });
      } else {
        setState(() {
          _promosError = res.message ?? 'Урамшууллын жагсаалт ачаалахад алдаа гарлаа.';
          _loadingPromos = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _promosError = 'Урамшууллын жагсаалт ачаалахад алдаа гарлаа: $e';
        _loadingPromos = false;
      });
    }
  }

  Future<void> _fetchReport() async {
    final auth = context.read<AuthModel>();
    final pos = auth.posSession;
    if (pos == null) return;

    setState(() {
      _loadingReport = true;
      _reportError = null;
    });

    try {
      final bodyData = tailanService.uramshuulalDelgerenguiBody(
        baiguullagiinId: pos.baiguullagiinId,
        salbariinId: pos.salbariinId,
        ekhlekh: _range.start,
        duusakh: _range.end,
      );

      // ДЭЛГЭРЭНГҮЙ тайланг уншина: нэгтгэсэн `/uramshuulliinTovchooTailanAvya`
      // нь баримтын дугаар, огноог буцаадаггүй.
      final res = await posApiService.post<List<dynamic>>(
        '/uramshuulliinDelgerenguiTailanAvya',
        body: bodyData,
        parser: (d) => d is List ? d : [],
      );

      if (!mounted) return;

      if (res.success && res.data != null) {
        final list = res.data!
            .whereType<Map>()
            .map((e) => UramshuulalReportRow.fromJson(
                Map<String, dynamic>.from(e)))
            .toList()
          // Хамгийн сүүлийн баримт эхэнд.
          ..sort((a, b) => (b.ognoo ?? DateTime(0))
              .compareTo(a.ognoo ?? DateTime(0)));
        double sumDisc = 0.0;
        double sumCnt = 0;

        for (final item in list) {
          sumDisc += item.amount;
          sumCnt += item.too;
        }

        setState(() {
          _reportItems = list;
          _totalReportDiscount = sumDisc;
          _totalReportCount = sumCnt;
          _loadingReport = false;
        });
      } else {
        setState(() {
          _reportError = res.message ?? 'Тайлан ачаалахад алдаа гарлаа.';
          _loadingReport = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportError = 'Тайлан ачаалахад алдаа гарлаа: $e';
        _loadingReport = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final body = Column(
      children: [
        Material(
          color: colorScheme.surface,
          elevation: 1,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.card_giftcard_rounded, size: 20),
                text: 'Урамшуулал',
              ),
              Tab(
                icon: Icon(Icons.analytics_rounded, size: 20),
                text: 'Урамшууллын тайлан',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPromotionsTab(colorScheme, theme.textTheme, l10n),
              _buildReportTab(colorScheme, theme.textTheme, l10n),
            ],
          ),
        ),
      ],
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Урамшуулал'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _fetchPromotions();
              _fetchReport();
            },
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildPromotionsTab(
    ColorScheme colorScheme,
    TextTheme textTheme,
    AppLocalizations l10n,
  ) {
    if (_loadingPromos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_promosError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_promosError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _fetchPromotions,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Дахин оролдох'),
              ),
            ],
          ),
        ),
      );
    }

    if (_promotions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard_outlined, size: 64, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'Урамшуулал бүртгэгдээгүй байна',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPromotions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _promotions.length,
        itemBuilder: (context, i) {
          final p = _promotions[i];
          final ner = p['ner']?.toString() ?? 'Урамшуулал';
          final turul = UramshuulalService.turulLabel(p['turul']?.toString());
          final startD = DateTime.tryParse(p['ekhlekhOgnoo']?.toString() ?? '');
          final endD = DateTime.tryParse(p['duusakhOgnoo']?.toString() ?? '');
          final now = DateTime.now();

          final bool isActive = startD != null &&
              endD != null &&
              !now.isBefore(startD) &&
              !now.isAfter(endD);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
            onTap: () => _showPromoDetail(p),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Гарчиг нь БҮТЭН мөрөө эзэлнэ. Өмнө нь нэр, төрөл, төлөв,
                  // ⋮ дөрвөв нэг мөрөнд шахагдаж, утсан дээр нэр нь 3 мөр
                  // болж тасарч, уншигдахгүй байв.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isActive ? AppColors.success : colorScheme.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.local_offer_rounded,
                          color: isActive ? AppColors.success : colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ner,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppColors.successContainer
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isActive ? 'Идэвхтэй' : 'Дууссан',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: isActive
                                          ? AppColors.onSuccessContainer
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  turul,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Анхдагч PopupMenu нь картаа халхлан таслаад, хэв
                      // маягийн хувьд ч апп-ын бусад цэснээс тасардаг байсан
                      // тул доод хуудас (bottom sheet) болгов.
                      IconButton(
                        tooltip: 'Үйлдэл',
                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                        onPressed: () => _showPromoActions(p),
                      ),
                    ],
                  ),
                  if (startD != null && endD != null) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.date_range_rounded,
                            size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'Хугацаа: ${MongolianDateFormatter.formatShortDate(startD)} — ${MongolianDateFormatter.formatShortDate(endD)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  // ── Урамшууллын үйлдлүүд ────────────────────────────────────────────────

  /// Картны ⋮ үйлдлүүд — доод хуудсаар.
  ///
  /// Апп-ын бусад цэснүүдтэй (бараа задлах, бөөний үнэ, урамшуулал сонгох)
  /// ижил хэлбэртэй байснаар товчнууд бүтэн өргөнтэй, хүрэхэд том, картаа
  /// халхлахгүй.
  Future<void> _showPromoActions(Map<String, dynamic> p) async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ner = p['ner']?.toString() ?? 'Урамшуулал';

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                ner,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Дэлгэрэнгүй'),
              onTap: () => Navigator.pop(ctx, 'detail'),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat_rounded),
              title: const Text('Хугацаа сунгах'),
              onTap: () => Navigator.pop(ctx, 'extend'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: cs.error),
              title: Text('Устгах', style: TextStyle(color: cs.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'detail') _showPromoDetail(p);
    if (action == 'extend') await _extendPromo(p);
    if (action == 'delete') await _deletePromo(p);
  }

  Future<void> _extendPromo(Map<String, dynamic> p) async {
    final id = (p['_id'] ?? p['id'])?.toString() ?? '';
    if (id.isEmpty) return;
    final startD =
        DateTime.tryParse(p['ekhlekhOgnoo']?.toString() ?? '') ?? DateTime.now();
    final endD =
        DateTime.tryParse(p['duusakhOgnoo']?.toString() ?? '') ?? DateTime.now();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(startD.year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
      initialDateRange: DateTimeRange(
        start: startD,
        end: endD.isAfter(startD) ? endD : startD,
      ),
      helpText: 'Шинэ хугацаа сонгох',
    );
    if (picked == null || !mounted) return;

    final ok = await uramshuulalService.khugatsaaSungya(
      id: id,
      ekhlekhOgnoo: picked.start,
      duusakhOgnoo: DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
      ),
    );
    if (!mounted) return;
    showAppSnackBar(
      context,
      ok ? 'Хугацаа сунгагдлаа' : 'Хугацаа сунгахад алдаа гарлаа',
      variant: ok ? AppSnackVariant.success : AppSnackVariant.error,
    );
    if (ok) await _fetchPromotions();
  }

  Future<void> _deletePromo(Map<String, dynamic> p) async {
    final id = (p['_id'] ?? p['id'])?.toString() ?? '';
    if (id.isEmpty) return;
    final ner = p['ner']?.toString() ?? 'Урамшуулал';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Урамшуулал устгах уу?'),
        content: Text('"$ner" урамшууллыг устгахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final ok = await uramshuulalService.ustga(id);
    if (!mounted) return;
    showAppSnackBar(
      context,
      ok ? 'Урамшуулал устгагдлаа' : 'Устгахад алдаа гарлаа',
      variant: ok ? AppSnackVariant.success : AppSnackVariant.error,
    );
    if (ok) await _fetchPromotions();
  }

  void _showPromoDetail(Map<String, dynamic> p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PromoDetailSheet(promo: p),
    );
  }

  Widget _buildReportTab(
    ColorScheme colorScheme,
    TextTheme textTheme,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: AppDateRangeFilterButton(
                  range: _range,
                  onPressed: (picked) {
                    setState(() => _range = picked);
                    _fetchReport();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _fetchReport,
              ),
            ],
          ),
        ),
        if (_loadingReport)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_reportError != null)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_reportError!, textAlign: TextAlign.center),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchReport,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Summary tile
                  Card(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Нийт олгосон урамшууллын өртөг',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  MntAmountFormatter.formatTugrikSpaced(_totalReportDiscount),
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Өгсөн тоо',
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_totalReportCount % 1 == 0 ? _totalReportCount.toStringAsFixed(0) : _totalReportCount.toStringAsFixed(2)} удаа',
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_reportItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'Сонгосон огноонд урамшуулал бүртгэгдээгүй байна',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._reportItems.map((item) {
                      final count = item.too % 1 == 0
                          ? item.too.toStringAsFixed(0)
                          : item.too.toStringAsFixed(2);
                      final meta = <String>[
                        if (item.code.isNotEmpty) item.code,
                        'Өгсөн тоо: $count ${item.unitLabel}',
                      ].join('  ·  ');
                      final receipt = <String>[
                        if (item.barimtiinDugaar != null &&
                            item.barimtiinDugaar!.isNotEmpty)
                          '№ ${item.barimtiinDugaar}',
                        if (item.ognoo != null)
                          MongolianDateFormatter.formatShortDate(item.ognoo!),
                      ].join('  ·  ');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.card_giftcard_rounded),
                          title: Text(item.ner,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(meta),
                              if (receipt.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    receipt,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          isThreeLine: receipt.isNotEmpty,
                          trailing: Text(
                            // Үнэ огт бүртгэгдээгүй бол "0.00" гэж төөрөгдүүлэхээс
                            // илүү "—" гэж шууд хэлнэ.
                            item.hasNoPrice
                                ? '—'
                                : MntAmountFormatter.format(item.amount),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: item.hasNoPrice
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.primary,
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
      ],
    );
  }
}


/// Урамшууллын дэлгэрэнгүй — нөхцөл, бэлэг, хугацаа, сунгалтын түүх.
class _PromoDetailSheet extends StatelessWidget {
  const _PromoDetailSheet({required this.promo});

  final Map<String, dynamic> promo;

  static String _d(dynamic v) {
    final t = DateTime.tryParse(v?.toString() ?? '');
    return t == null ? '—' : MongolianDateFormatter.formatShortDate(t);
  }

  static List<Map<String, dynamic>> _rows(dynamic v) {
    if (v is! List) return const [];
    return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nukhtsul = _rows(promo['uramshuulaliinNukhtsul']);
    final beleg = _rows(promo['uramshuulaliinBeleg']);
    final sungalt = _rows(promo['sungaltiinTuukh']);
    final angilal = (promo['angilal'] is List)
        ? (promo['angilal'] as List).map((e) => e.toString()).toList()
        : const <String>[];

    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 130,
                child: Text(k,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Expanded(
                child: Text(v,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    Widget baraaList(String title, List<Map<String, dynamic>> rows) {
      if (rows.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(title,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r['baraaniiNer']?.toString() ??
                          r['baraaniiDotoodCode']?.toString() ??
                          '—',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium,
                    ),
                  ),
                  Text('${r['too'] ?? 0} ш',
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              promo['ner']?.toString() ?? 'Урамшуулал',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            line('Төрөл', UramshuulalService.turulLabel(promo['turul']?.toString())),
            line('Эхлэх', _d(promo['ekhlekhOgnoo'])),
            line('Дуусах', _d(promo['duusakhOgnoo'])),
            if (promo['buleg'] != null)
              line('Бүлэг (N)', promo['buleg'].toString()),
            if (promo['chuluulekhToo'] != null)
              line('Үнэгүй (M)', promo['chuluulekhToo'].toString()),
            if (promo['khuree'] != null)
              line(
                'Хамрах хүрээ',
                promo['khuree'] == 'angilal' ? 'Ангилал' : 'Бүх бараа',
              ),
            if (angilal.isNotEmpty) line('Ангилал', angilal.join(', ')),
            if (promo['burtegsenAjiltan'] is Map)
              line(
                'Бүртгэсэн',
                (promo['burtegsenAjiltan'] as Map)['ner']?.toString() ?? '—',
              ),
            baraaList('Нөхцөл (эдгээрийг авбал)', nukhtsul),
            baraaList('Бэлэг (эдгээрийг үнэгүй)', beleg),
            if (sungalt.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Сунгалтын түүх',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final r in sungalt)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${_d(r['ekhlekhOgnoo'])} — ${_d(r['duusakhOgnoo'])}'
                    '${(r['sungasanAjiltan'] is Map && (r['sungasanAjiltan'] as Map)['ner'] != null) ? '  ·  ${(r['sungasanAjiltan'] as Map)['ner']}' : ''}',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
