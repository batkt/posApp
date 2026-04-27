import 'package:flutter/material.dart';

import '../utils/mongolian_date_formatter.dart';

/// Same pattern as [IncomeOverviewScreen] (Орлого): compact `yyyy-MM-dd — yyyy-MM-dd`, not full-width.
class AppDateRangeFilterButton extends StatelessWidget {
  const AppDateRangeFilterButton({
    super.key,
    required this.range,
    required this.onPressed,
    this.padding = EdgeInsets.zero,
  });

  final DateTimeRange range;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = MongolianDateFormatter.formatDateRangeCompact(
      range.start,
      range.end,
    );
    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.date_range_rounded, size: 20),
          label: Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    );
  }
}
