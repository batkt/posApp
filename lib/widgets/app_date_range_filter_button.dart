import 'package:flutter/material.dart';

import '../utils/app_date_range_picker.dart';
import '../utils/mongolian_date_formatter.dart';
import '../models/locale_model.dart';

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

  static DateTimeRange _thisYear() {
    final n = DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, 1, 1),
      end: DateTime(n.year, 12, 31, 23, 59, 59),
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
      ('Энэ 7 хоног', _thisWeek()),
      ('Сүүлийн 7 хоног', _last7()),
      ('Энэ сар', _thisMonth()),
      ('Өмнөх сар', _lastMonth()),
      ('Сүүлийн 30 хоног', _last30()),
      ('Энэ жил', _thisYear()),
    ];

    final isPresetActive = presets.any((p) => _isActive(p.$2));
    final isCustomActive = !isPresetActive;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
            const SizedBox(height: 8),

            // Header row
            Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: Text(
                    'Хугацаа сонгох',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip:
                      MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Preset grid (2 columns, balanced height)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 42,
              ),
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final p = presets[index];
                final active = _isActive(p.$2);
                return Material(
                  color: active
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(context, p.$2),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active
                              ? colorScheme.primary
                              : colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        p.$1,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Custom range picker card
            Material(
              color: isCustomActive
                  ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                  : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showAppDateRangePicker(
                    context: context,
                    initialDateRange: current,
                    firstDate: DateTime(2018),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCustomActive
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.6),
                      width: isCustomActive ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: isCustomActive
                              ? colorScheme.primary
                              : colorScheme.primaryContainer
                                  .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            color: isCustomActive
                                ? colorScheme.onPrimary
                                : colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Өөр огноо сонгох',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              MongolianDateFormatter.formatDateRangeCompact(
                                current.start,
                                current.end,
                              ),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isCustomActive
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
