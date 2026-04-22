import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/locale_model.dart';

/// Client-side filter: [year] null → any year; [month] null → any month within [year].
bool saleMatchesYearMonthFilter(
  DateTime timestamp,
  int? year,
  int? month,
) {
  if (year == null) return true;
  if (timestamp.year != year) return false;
  if (month == null) return true;
  return timestamp.month == month;
}

/// Year + month dropdowns for receipt / e-barimt lists (no API change).
class SaleYearMonthFilterBar extends StatelessWidget {
  const SaleYearMonthFilterBar({
    super.key,
    required this.l10n,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onFilterChanged,
  });

  final AppLocalizations l10n;
  final int? selectedYear;
  final int? selectedMonth;
  final void Function(int? year, int? month) onFilterChanged;

  static List<int?> _yearValues(DateTime now) {
    final minY = now.year - 10;
    final maxY = now.year + 1;
    return [null, for (var y = minY; y <= maxY; y++) y];
  }

  String _monthLabel(BuildContext context, int month) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'mn') {
      return '$month-р сар';
    }
    return DateFormat.MMMM(locale.toString()).format(DateTime(2000, month));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final years = _yearValues(now);

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    );

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: border,
          enabledBorder: border,
        );

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: years.contains(selectedYear) ? selectedYear : null,
                isExpanded: true,
                decoration: deco(l10n.tr('sales_filter_year')),
                items: years
                    .map(
                      (y) => DropdownMenuItem<int?>(
                        value: y,
                        child: Text(
                          y == null
                              ? l10n.tr('sales_filter_all_years')
                              : '$y',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) {
                    onFilterChanged(null, null);
                  } else {
                    onFilterChanged(v, selectedMonth);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: selectedYear == null ? null : selectedMonth,
                isExpanded: true,
                decoration: deco(l10n.tr('sales_filter_month')),
                items: selectedYear == null
                    ? [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            l10n.tr('sales_filter_pick_year_first'),
                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ]
                    : [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(l10n.tr('sales_filter_all_months')),
                        ),
                        ...List.generate(
                          12,
                          (i) {
                            final m = i + 1;
                            return DropdownMenuItem<int?>(
                              value: m,
                              child: Text(
                                _monthLabel(context, m),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ],
                onChanged: selectedYear == null
                    ? null
                    : (v) => onFilterChanged(selectedYear, v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
