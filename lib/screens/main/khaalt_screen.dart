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
  const KhaaltScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<KhaaltScreen> createState() => _KhaaltScreenState();
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
    final enabled = tokhirgoo is! Map || tokhirgoo['khaaltAshiglakhEsekh'] == true;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(l10n.tr('khaalt_title')),
              centerTitle: true,
              actions: [
                if (!_loading)
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).refreshIndicatorLabel,
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
              ],
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _body(context, l10n, colorScheme, textTheme),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (_loadErrorKey != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.tr(_loadErrorKey!),
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
          ),
        ),
      );
    }

    if (!_khaaltEnabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.tr('khaalt_disabled'),
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge,
          ),
        ),
      );
    }

    if (!_hasValidSelectableRange) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 48, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                l10n.tr('khaalt_no_dates_left'),
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_lastCloseLocalDay != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${l10n.tr('khaalt_last_close')}: ${_lastCloseLocalDay!.year}-'
              '${_lastCloseLocalDay!.month.toString().padLeft(2, '0')}-'
              '${_lastCloseLocalDay!.day.toString().padLeft(2, '0')}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.tr('khaalt_date_label')),
          subtitle: Text(
            '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-'
            '${_selectedDay.day.toString().padLeft(2, '0')}',
            style: textTheme.titleMedium,
          ),
          trailing: const Icon(Icons.calendar_today_rounded),
          onTap: () => _pickDate(l10n),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.tr('khaalt_denoms_head'),
          style: textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ..._denoms.map((d) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    MntAmountFormatter.formatTugrik(d),
                    style: textTheme.bodyMedium,
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
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        TextField(
          controller: _tailbarController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.tr('khaalt_note'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.tr('khaalt_total'), style: textTheme.titleMedium),
            Text(
              MntAmountFormatter.formatTugrik(_niitDun),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _submitting ? null : () => _submit(l10n),
          icon: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded),
          label: Text(l10n.tr('khaalt_submit')),
        ),
      ],
    );
  }
}
