import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../models/pos_session.dart';
import '../../services/khaalt_service.dart';
import '../../services/pos_settings_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';

/// Web parity: cash drawer close (`khaalt`) with denomination counts.
class KhaaltScreen extends StatefulWidget {
  const KhaaltScreen({
    super.key,
    this.showAppBar = true,
    this.embeddedDialog = false,
  });

  final bool showAppBar;

  /// Layout for [showKhaaltModal]: column with header + divider + scroll body (no [Scaffold]).
  final bool embeddedDialog;

  @override
  State<KhaaltScreen> createState() => _KhaaltScreenState();
}

/// Cash register close as a full-width bottom sheet — kiosk / mobile cashier AppBar.
Future<void> showKhaaltModal(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;

  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      minWidth: width,
      maxWidth: width,
    ),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final m = MediaQuery.of(ctx);
      final kb = m.viewInsets.bottom;
      // Space above keyboard (and safe area); avoid fixed 92% of full screen — that overflows when keyboard is up.
      final usable = m.size.height - m.padding.top - m.padding.bottom - kb;
      final sheetHeight = math.min(math.max(usable * 0.92, 200.0), usable);

      return Padding(
        padding: EdgeInsets.only(bottom: kb),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Material(
            color: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            child: SizedBox(
              width: width,
              height: sheetHeight,
              child: const KhaaltScreen(
                showAppBar: false,
                embeddedDialog: true,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _KhaaltScreenState extends State<KhaaltScreen> {
  static const List<int> _denoms = [
    20000,
    10000,
    5000,
    1000,
    500,
    100,
    50,
    20,
    10,
  ];

  final Map<int, TextEditingController> _countControllers = {
    for (final d in _denoms) d: TextEditingController(),
  };
  final TextEditingController _tailbarController = TextEditingController();

  bool _loading = true;
  String? _loadErrorKey;
  bool _khaaltEnabled = true;
  DateTime? _lastCloseLocalDay;
  DateTime _selectedDay = _dateOnly(DateTime.now());
  bool _submitting = false;

  PosSession? get _session => context.read<AuthModel>().posSession;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime? _parseOgnoo(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final p = DateTime.tryParse(v);
      return p != null ? _dateOnly(p.toLocal()) : null;
    }
    if (v is Map) {
      final inner = v[r'$date'];
      if (inner is String) {
        final p = DateTime.tryParse(inner);
        return p != null ? _dateOnly(p.toLocal()) : null;
      }
      if (inner is int) {
        return _dateOnly(
          DateTime.fromMillisecondsSinceEpoch(inner, isUtc: true).toLocal(),
        );
      }
    }
    return null;
  }

  DateTime get _firstAllowedDay {
    final last = _lastCloseLocalDay;
    if (last == null) return DateTime(2000);
    return _dateOnly(last).add(const Duration(days: 1));
  }

  DateTime get _lastSelectableDay => _dateOnly(DateTime.now());

  bool get _hasValidSelectableRange =>
      !_firstAllowedDay.isAfter(_lastSelectableDay);

  int get _niitDun {
    var sum = 0;
    for (final d in _denoms) {
      final raw = _countControllers[d]?.text.trim() ?? '';
      final n = int.tryParse(raw) ?? 0;
      if (n > 0) sum += d * n;
    }
    return sum;
  }

  @override
  void initState() {
    super.initState();
    for (final c in _countControllers.values) {
      c.addListener(() => setState(() {}));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final session = _session;
    final auth = context.read<AuthModel>();
    if (session == null || !auth.canSubmitPosSales) {
      setState(() {
        _loading = false;
        _loadErrorKey = 'pos_settings_no_session';
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadErrorKey = null;
    });

    final staffId = session.ajiltan['_id']?.toString() ?? '';
    if (staffId.isEmpty) {
      setState(() {
        _loading = false;
        _loadErrorKey = 'pos_settings_no_session';
      });
      return;
    }

    final orgF = posSettingsService.fetchBaiguullaga(session.baiguullagiinId);
    final lastF = khaaltService.fetchSuuliinKhaalt(
      baiguullagiinId: session.baiguullagiinId,
      salbariinId: session.salbariinId,
      burtgesenAjiltan: staffId,
    );

    final org = await orgF;
    final lastDoc = await lastF;

    if (!mounted) return;

    final tokhirgoo = org?['tokhirgoo'];
    // Web: `baiguullaga?.tokhirgoo?.khaaltAshiglakhEsekh` must be true to show Khaalt.
    final enabled =
        tokhirgoo is Map && tokhirgoo['khaaltAshiglakhEsekh'] == true;

    DateTime? lastDay;
    if (lastDoc != null && lastDoc.isNotEmpty) {
      lastDay = _parseOgnoo(lastDoc['ognoo']);
    }

    final first = lastDay == null
        ? _dateOnly(DateTime.now())
        : _dateOnly(lastDay).add(const Duration(days: 1));
    final lastSel = _dateOnly(DateTime.now());
    final initial = first.isAfter(lastSel) ? lastSel : first;

    setState(() {
      _loading = false;
      _khaaltEnabled = enabled;
      _lastCloseLocalDay = lastDay;
      _selectedDay = initial;
      if (org == null) _loadErrorKey = 'pos_settings_load_failed';
    });
  }

  String _ognooIsoForSubmit(DateTime localDay) {
    final start = DateTime(localDay.year, localDay.month, localDay.day);
    return start.toUtc().toIso8601String();
  }

  Future<void> _pickDate(AppLocalizations l10n) async {
    if (!_hasValidSelectableRange) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay.isBefore(_firstAllowedDay)
          ? _firstAllowedDay
          : (_selectedDay.isAfter(_lastSelectableDay)
              ? _lastSelectableDay
              : _selectedDay),
      firstDate: _firstAllowedDay,
      lastDate: _lastSelectableDay,
      helpText: l10n.tr('khaalt_date_label'),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDay = _dateOnly(picked));
    }
  }

  Future<void> _submit(AppLocalizations l10n) async {
    final session = _session;
    if (session == null || !_khaaltEnabled || _submitting) return;

    final staffId = session.ajiltan['_id']?.toString() ?? '';
    final ner =
        session.ajiltan['ner']?.toString() ?? session.ajiltan['name']?.toString() ?? '';

    final mungunTemdegt = <Map<String, dynamic>>[];
    for (final d in _denoms) {
      final raw = _countControllers[d]?.text.trim() ?? '';
      final n = int.tryParse(raw) ?? 0;
      if (n > 0) {
        mungunTemdegt.add({'temdegt': d.toString(), 'too': n});
      }
    }

    if (mungunTemdegt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('khaalt_need_counts')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sel = _dateOnly(_selectedDay);
    final last = _lastCloseLocalDay;
    if (last != null) {
      final lastD = _dateOnly(last);
      if (!sel.isAfter(lastD)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tr('khaalt_date_invalid')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (sel.isAfter(_lastSelectableDay)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('khaalt_date_invalid')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final ok = await khaaltService.submitKhaalt({
      'ognoo': _ognooIsoForSubmit(sel),
      'mungunTemdegt': mungunTemdegt,
      'niitDun': _niitDun,
      'tailbar': _tailbarController.text.trim(),
      'burtgesenAjiltan': staffId,
      'burtgesenAjiltaniiNer': ner,
      'baiguullagiinId': session.baiguullagiinId,
      'salbariinId': session.salbariinId,
      'turul': 'pos',
    });

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      for (final c in _countControllers.values) {
        c.clear();
      }
      _tailbarController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('khaalt_success')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('khaalt_submit_failed')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tailbarController.dispose();
    for (final c in _countControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _dialogChrome(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            colorScheme.surface,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.tr('khaalt_title'),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: Icon(
              Icons.refresh_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonLabel,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _loadingState(ColorScheme colorScheme) {
    return Center(
      child: SizedBox(
        width: 42,
        height: 42,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required Color iconColor,
    required String message,
    required TextStyle? textStyle,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: iconColor),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _denomRow(
    int d,
    AppLocalizations l10n,
    TextTheme textTheme,
    ColorScheme colorScheme,
    double labelWidth,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                MntAmountFormatter.formatTugrik(d),
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _countControllers[d],
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: l10n.tr('khaalt_count'),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _denomsSection(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    double maxWidth,
  ) {
    final wide = maxWidth >= 460;
    final gap = wide ? 12.0 : 0.0;
    final labelW = wide ? 88.0 : math.min(80.0, maxWidth * 0.22);

    final rows = _denoms.map((d) {
      return wide
          ? SizedBox(
              width: (maxWidth - gap) / 2,
              child: _denomRow(d, l10n, textTheme, colorScheme, labelW),
            )
          : _denomRow(d, l10n, textTheme, colorScheme, labelW);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            l10n.tr('khaalt_denoms_head'),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        if (wide)
          Wrap(spacing: gap, runSpacing: 0, children: rows)
        else
          Column(children: rows),
      ],
    );
  }

  Widget _dateCard(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final dateStr =
        '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-'
        '${_selectedDay.day.toString().padLeft(2, '0')}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickDate(l10n),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('khaalt_date_label'),
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalAndSubmit(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colorScheme.primaryContainer.withValues(alpha: 0.75),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.tr('khaalt_total'),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                MntAmountFormatter.formatTugrik(_niitDun),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _submitting ? null : () => _submit(l10n),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      l10n.tr('khaalt_submit'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _formFieldWidgets(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    double maxWidth,
  ) {
    return [
      if (_lastCloseLocalDay != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.tr('khaalt_last_close')}: '
                  '${_lastCloseLocalDay!.year}-'
                  '${_lastCloseLocalDay!.month.toString().padLeft(2, '0')}-'
                  '${_lastCloseLocalDay!.day.toString().padLeft(2, '0')}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      _dateCard(l10n, colorScheme, textTheme),
      const SizedBox(height: 18),
      _denomsSection(l10n, colorScheme, textTheme, maxWidth),
      const SizedBox(height: 12),
      TextField(
        controller: _tailbarController,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: l10n.tr('khaalt_note'),
          filled: true,
          fillColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          alignLabelWithHint: true,
        ),
      ),
    ];
  }

  Widget _formScrollable(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    double maxWidth, {
    required bool embedFooterBelow,
  }) {
    final padH = maxWidth >= 480 ? 20.0 : 14.0;
    final bottomSafe =
        embedFooterBelow ? 0.0 : MediaQuery.paddingOf(context).bottom;
    final bottomPad = embedFooterBelow ? 8.0 : 28.0 + bottomSafe;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(padH, 12, padH, bottomPad),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._formFieldWidgets(l10n, colorScheme, textTheme, maxWidth),
          if (!embedFooterBelow) ...[
            const SizedBox(height: 20),
            _totalAndSubmit(l10n, colorScheme, textTheme),
          ],
        ],
      ),
    );
  }

  /// Scrollable form for embedded bottom sheet (must live inside [Expanded]).
  Widget _formListView(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    double maxWidth,
  ) {
    final padH = maxWidth >= 480 ? 20.0 : 14.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(padH, 12, padH, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: _formFieldWidgets(l10n, colorScheme, textTheme, maxWidth),
    );
  }

  Widget _embeddedStickyFooter(
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
    double footerBottomInset,
  ) {
    return Material(
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + footerBottomInset,
        ),
        child: _totalAndSubmit(l10n, colorScheme, textTheme),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final footerBottomInset = mq.viewInsets.bottom > 0
        ? mq.viewInsets.bottom
        : mq.padding.bottom;

    final mainContent = _loading
        ? _loadingState(colorScheme)
        : _body(
            context,
            l10n,
            colorScheme,
            textTheme,
            footerBottomInset: footerBottomInset,
          );

    if (widget.embeddedDialog) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dialogChrome(context, l10n, colorScheme, textTheme),
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          Expanded(child: mainContent),
        ],
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.tr('khaalt_title')),
              centerTitle: true,
              actions: [
                if (!_loading)
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            )
          : null,
      body: mainContent,
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    double footerBottomInset = 0,
  }) {
    if (_loadErrorKey != null) {
      return _messageState(
        icon: Icons.error_outline_rounded,
        iconColor: colorScheme.error,
        message: l10n.tr(_loadErrorKey!),
        textStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
      );
    }

    if (!_khaaltEnabled) {
      return _messageState(
        icon: Icons.block_rounded,
        iconColor: colorScheme.onSurfaceVariant,
        message: l10n.tr('khaalt_disabled'),
        textStyle: textTheme.bodyLarge,
      );
    }

    if (!_hasValidSelectableRange) {
      return _messageState(
        icon: Icons.event_busy_rounded,
        iconColor: colorScheme.primary,
        message: l10n.tr('khaalt_no_dates_left'),
        textStyle: textTheme.titleMedium,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        if (widget.embeddedDialog) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _formListView(
                  context,
                  l10n,
                  colorScheme,
                  textTheme,
                  w,
                ),
              ),
              _embeddedStickyFooter(
                l10n,
                colorScheme,
                textTheme,
                footerBottomInset,
              ),
            ],
          );
        }

        return _formScrollable(
          context,
          l10n,
          colorScheme,
          textTheme,
          w,
          embedFooterBelow: false,
        );
      },
    );
  }
}
