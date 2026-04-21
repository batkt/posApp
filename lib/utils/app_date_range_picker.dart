import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/locale_model.dart';

/// [showDateRangePicker] with app [Locale] and localized title / actions.
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
  );
}
