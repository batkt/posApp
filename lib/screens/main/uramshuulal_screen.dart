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

/// Screen for managing & viewing Promotions (Урамшуулал) and Promotion Reports.
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
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  List<Map<String, dynamic>> _reportItems = [];
  double _totalReportDiscount = 0.0;
  int _totalReportCount = 0;

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
      final bodyData = tailanService.uramshuulalTovchooBody(
        baiguullagiinId: pos.baiguullagiinId,
        salbariinId: pos.salbariinId,
        ekhlekh: _range.start,
        duusakh: _range.end,
      );

      final res = await posApiService.post<List<dynamic>>(
        '/uramshuulalTovchoo',
        body: bodyData,
        parser: (d) => d is List ? d : [],
      );

      if (!mounted) return;

      if (res.success && res.data != null) {
        final list = res.data!.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        double sumDisc = 0.0;
        int sumCnt = 0;

        for (final item in list) {
          sumDisc += (item['hungulsunDun'] as num?)?.toDouble() ?? 0.0;
          sumCnt += (item['too'] as num?)?.toInt() ?? 0;
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
          final turul = p['turul']?.toString() ?? 'Бусад';
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Төрөл: $turul',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          );
        },
      ),
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
                                  'Нийт олгосон урамшуулал',
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
                                'Ашиглагдсан тоо',
                                style: textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_totalReportCount удаа',
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
                      final name = item['_id']?['ner']?.toString() ??
                          item['ner']?.toString() ??
                          'Урамшуулал';
                      final discount = (item['hungulsunDun'] as num?)?.toDouble() ?? 0.0;
                      final count = (item['too'] as num?)?.toInt() ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.card_giftcard_rounded),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Ашиглагдсан: $count удаа'),
                          trailing: Text(
                            MntAmountFormatter.format(discount),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
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
