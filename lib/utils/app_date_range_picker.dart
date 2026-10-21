import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/locale_model.dart';

/// [showDateRangePicker] with app [Locale], custom styled header to avoid text truncation,
/// and harmonious theme colors.
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTimeRange initialDateRange,
  required String helpText,
  required String cancelText,
  required String confirmText,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final locale = context.read<LocaleModel>().locale;
  return showDateRangePicker(
    context: context,
    firstDate: firstDate ?? DateTime(2020),
    lastDate: lastDate ?? DateTime(2100),
    initialDateRange: initialDateRange,
    locale: locale,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
    builder: (BuildContext ctx, Widget? child) {
      final theme = Theme.of(ctx);
      final cs = theme.colorScheme;
      return Theme(
        data: theme.copyWith(
          datePickerTheme: DatePickerThemeData(
            headerHeadlineStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            rangePickerHeaderHeadlineStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            headerHelpStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
            rangePickerHeaderHelpStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
            headerBackgroundColor: cs.surface,
            headerForegroundColor: cs.onSurface,
            rangePickerBackgroundColor: cs.surface,
            rangeSelectionBackgroundColor:
                cs.primaryContainer.withValues(alpha: 0.55),
            todayForegroundColor: WidgetStateProperty.all(cs.primary),
            todayBorder: BorderSide(color: cs.primary, width: 1.5),
            dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return cs.primary;
              }
              return null;
            }),
            dayForegroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return cs.onPrimary;
              }
              return null;
            }),
          ),
        ),
        child: child!,
      );
    },
  );
}
