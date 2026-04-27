import 'package:flutter/material.dart';

import '../utils/app_date_range_picker.dart';
import '../utils/mongolian_date_formatter.dart';
import '../models/locale_model.dart';
import 'package:provider/provider.dart';

/// Centered, full-width date range filter button used consistently on every
/// screen (Орлого, Тайлан, Худалдан авалт, Тооллого, …).
///
/// Tapping opens a bottom-sheet with quick presets **+ custom range picker**.
class AppDateRangeFilterButton extends StatelessWidget {
  const AppDateRangeFilterButton({
    super.key,
    required this.range,
    required this.onPressed,
    this.padding = EdgeInsets.zero,
  });

  final DateTimeRange range;

  /// Called with the **new** range after the user confirms a selection.
  /// The caller is responsible for `setState` as usual.
  final ValueChanged<DateTimeRange> onPressed;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = MongolianDateFormatter.formatDateRangeCompact(
      range.start,
      range.end,
    );

    return Padding(
      padding: padding,
      child: Center(
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _showSheet(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: colorScheme.primary.withValues(alpha: 0.55),
                width: 1.4,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DateRangeSheet(current: range),
    );
    if (picked != null) onPressed(picked);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-sheet with presets + custom range
// ─────────────────────────────────────────────────────────────────────────────

class _DateRangeSheet extends StatelessWidget {
  const _DateRangeSheet({required this.current});

  final DateTimeRange current;

  static DateTimeRange _today() {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month, n.day),
      end: DateTime(n.year, n.month, n.day, 23, 59, 59),
    );
  }

  static DateTimeRange _yesterday() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    return DateTimeRange(
      start: DateTime(n.year, n.month, n.day),
      end: DateTime(n.year, n.month, n.day, 23, 59, 59),
    );
  }

  static DateTimeRange _thisWeek() {
    final n = DateTime.now();
    final start = n.subtract(Duration(days: n.weekday - 1));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(n.year, n.month, n.day, 23, 59, 59),
    );
  }

  static DateTimeRange _thisMonth() {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month, 1),
      end: DateTime(n.year, n.month + 1, 0, 23, 59, 59),
    );
  }

  static DateTimeRange _lastMonth() {
    final n = DateTime.now();
    final first = DateTime(n.year, n.month - 1, 1);
    return DateTimeRange(
      start: first,
      end: DateTime(n.year, n.month, 0, 23, 59, 59),
    );
  }

  static DateTimeRange _last7() {
    final n = DateTime.now();
    final start = n.subtract(const Duration(days: 6));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(n.year, n.month, n.day, 23, 59, 59),
    );
  }

  static DateTimeRange _last30() {
    final n = DateTime.now();
    final start = n.subtract(const Duration(days: 29));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(n.year, n.month, n.day, 23, 59, 59),
    );
  }

  bool _isActive(DateTimeRange r) {
    return _sameDay(r.start, current.start) && _sameDay(r.end, current.end);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final presets = [
      ('Өнөөдөр', _today()),
      ('Өчигдөр', _yesterday()),
      ('Энэ долоо хоног', _thisWeek()),
      ('Сүүлийн 7 хоног', _last7()),
      ('Энэ сар', _thisMonth()),
      ('Сүүлийн 30 хоног', _last30()),
      ('Өмнөх сар', _lastMonth()),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              l10n.tr('date_picker_range_help'),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Preset chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: presets.map((p) {
                final active = _isActive(p.$2);
                return FilterChip(
                  label: Text(p.$1),
                  selected: active,
                  onSelected: (_) => Navigator.pop(context, p.$2),
                  labelStyle: textTheme.labelMedium?.copyWith(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  selectedColor: colorScheme.primary,
                  checkmarkColor: colorScheme.onPrimary,
                  showCheckmark: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),

            // Custom range picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_calendar_rounded,
                  color: colorScheme.secondary,
                  size: 20,
                ),
              ),
              title: Text(
                'Өдөр сонгох',
                style: textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                MongolianDateFormatter.formatDateRangeCompact(
                  current.start,
                  current.end,
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final picked = await showAppDateRangePicker(
                  context: context,
                  initialDateRange: current,
                  firstDate: DateTime(2018),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  helpText: l10n.tr('date_picker_range_help'),
                  cancelText: l10n.tr('date_picker_cancel'),
                  confirmText: l10n.tr('date_picker_confirm'),
                );
                if (picked == null || !context.mounted) return;
                final normalized = DateTimeRange(
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
                if (context.mounted) Navigator.pop(context, normalized);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
