import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/locale_model.dart';
import '../models/sales_model.dart';
import '../theme/app_theme.dart';
import '../utils/mnt_amount_formatter.dart';
import '../utils/mongolian_date_formatter.dart';
import 'authenticated_image.dart';

String _fmtMnt(double v) => MntAmountFormatter.formatTugrik(v);

String? _saleStaffCaption(Map<String, dynamic>? a) {
  if (a == null || a.isEmpty) return null;
  final ner = a['ner'] ?? a['name'];
  if (ner != null && ner.toString().trim().isNotEmpty) {
    return ner.toString().trim();
  }
  final login = a['burtgeliinDugaar'];
  if (login != null && login.toString().trim().isNotEmpty) {
    return login.toString().trim();
  }
  final id = a['id'] ?? a['_id'];
  if (id != null && id.toString().trim().isNotEmpty) {
    return id.toString().trim();
  }
  return null;
}

Widget _saleDetailPriceRow(
  String label,
  double amount,
  TextTheme textTheme,
  ColorScheme colorScheme, {
  bool isTotal = false,
  bool emphasize = true,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: isTotal
            ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
            : textTheme.bodyMedium?.copyWith(
                color: emphasize
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
      ),
      Text(
        _fmtMnt(amount),
        style: isTotal
            ? textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              )
            : textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      ),
    ],
  );
}

/// Same modal shell as [showKhaaltModal] (`khaalt_screen.dart`): fixed height,
/// transparent scrim + clip + elevation, inner [Column] with header / divider /
/// expanded scroll / sticky footer.
Future<void> showCompletedSaleDetailSheet(
  BuildContext context,
  CompletedSale sale,
) async {
  final width = MediaQuery.sizeOf(context).width;

  await showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(minWidth: width, maxWidth: width),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final m = MediaQuery.of(ctx);
      final kb = m.viewInsets.bottom;
      final usable =
          m.size.height - m.padding.top - m.padding.bottom - kb;
      final sheetHeight =
          math.min(math.max(usable * 0.92, 200.0), usable);

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
              child: CompletedSaleDetailPanel(sale: sale),
            ),
          ),
        ),
      );
    },
  );
}

class CompletedSaleDetailPanel extends StatelessWidget {
  const CompletedSaleDetailPanel({super.key, required this.sale});

  final CompletedSale sale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final footerBottomInset = mq.viewInsets.bottom > 0
        ? mq.viewInsets.bottom
        : mq.padding.bottom;
    final staffCap = _saleStaffCaption(sale.ajiltan);
    final maxW = mq.size.width;
    final padH = maxW >= 480 ? 20.0 : 14.0;

    String dateTimeLine() {
      final t = sale.timestamp.toLocal();
      final lang = Localizations.localeOf(context).languageCode;
      if (lang == 'mn') {
        return '${MongolianDateFormatter.formatShortDate(t)} · ${MongolianDateFormatter.formatTime(t, seconds: true)}';
      }
      return '${DateFormat.yMMMd().format(t)} · ${DateFormat.Hms().format(t)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.successContainer.withValues(alpha: 0.35),
                colorScheme.surface,
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successContainer.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.tr('sale_completed'),
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              IconButton(
                tooltip:
                    MaterialLocalizations.of(context).closeButtonTooltip,
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(padH, 12, padH, 16),
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                l10n.tr('sales_history_order_no'),
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                sale.id,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateTimeLine(),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (staffCap != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.tr('sales_history_staff'),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  staffCap,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Material(
                color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('total'),
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fmtMnt(sale.total),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onPrimaryContainer,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n
                            .tr('receipt_qty_summary')
                            .replaceAll(
                              '{pieces}',
                              '${sale.items.fold<int>(0, (s, i) => s + i.quantity)}',
                            )
                            .replaceAll('{lines}', '${sale.items.length}'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final item in sale.items)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AuthenticatedImage(
                      imageUrl: item.product.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    item.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${item.quantity} × ${_fmtMnt(item.unitPrice)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    _fmtMnt(item.total),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Material(
          elevation: 10,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          color: colorScheme.surfaceContainerLow,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padH,
              12,
              padH,
              12 + footerBottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _saleDetailPriceRow(
                  l10n.tr('subtotal'),
                  sale.subtotal,
                  textTheme,
                  colorScheme,
                ),
                if (sale.discount > 0.009) ...[
                  const SizedBox(height: 6),
                  _saleDetailPriceRow(
                    l10n.tr('discount'),
                    sale.discount,
                    textTheme,
                    colorScheme,
                    emphasize: false,
                  ),
                ],
                if (sale.tax > 0.009) ...[
                  const SizedBox(height: 6),
                  _saleDetailPriceRow(
                    l10n.tr('vat'),
                    sale.tax,
                    textTheme,
                    colorScheme,
                  ),
                ],
                if (sale.nhhat > 0.009) ...[
                  const SizedBox(height: 6),
                  _saleDetailPriceRow(
                    l10n.tr('nhhat_label'),
                    sale.nhhat,
                    textTheme,
                    colorScheme,
                  ),
                ],
                const Divider(height: 20),
                _saleDetailPriceRow(
                  l10n.tr('total'),
                  sale.total,
                  textTheme,
                  colorScheme,
                  isTotal: true,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: FilledButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                      backgroundColor: colorScheme.primary,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: Text(
                      l10n.tr('sales_history_close_detail'),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
