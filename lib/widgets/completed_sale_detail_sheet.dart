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

/// Premium modal shell — large bottom sheet with branded header, items list,
/// receipt-style breakdown, and a sticky action footer.
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
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(minWidth: width, maxWidth: width),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final m = MediaQuery.of(ctx);
      final kb = m.viewInsets.bottom;
      final usable = m.size.height - m.padding.top - m.padding.bottom - kb;
      final sheetHeight = math.min(math.max(usable * 0.94, 200.0), usable);

      return Padding(
        padding: EdgeInsets.only(bottom: kb),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.18),
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
    final footerBottomInset =
        mq.viewInsets.bottom > 0 ? mq.viewInsets.bottom : mq.padding.bottom;
    final staffCap = _saleStaffCaption(sale.ajiltan);
    final maxW = mq.size.width;
    final padH = maxW >= 480 ? 20.0 : 16.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        // ── Drag handle ──
        _DragHandle(colorScheme: colorScheme),

        // ── Branded header ──
        _SaleHeader(
          sale: sale,
          l10n: l10n,
          colorScheme: colorScheme,
          textTheme: textTheme,
          dateTimeLine: dateTimeLine(),
          staffCap: staffCap,
          padH: padH,
          isDark: isDark,
        ),

        // ── Scrollable content ──
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(padH, 16, padH, 8),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // Items section header
              _SectionLabel(
                icon: Icons.shopping_bag_outlined,
                label: l10n.tr('sales_history_items'),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 8),

              // Product items
              ...sale.items.map(
                (item) => _ProductItemCard(
                  item: item,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              ),

              const SizedBox(height: 4),
              _DashedDivider(color: colorScheme.outlineVariant),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Sticky totals + action footer ──
        _SaleFooter(
          sale: sale,
          l10n: l10n,
          colorScheme: colorScheme,
          textTheme: textTheme,
          padH: padH,
          footerBottomInset: footerBottomInset,
          isDark: isDark,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _SaleHeader extends StatelessWidget {
  const _SaleHeader({
    required this.sale,
    required this.l10n,
    required this.colorScheme,
    required this.textTheme,
    required this.dateTimeLine,
    required this.staffCap,
    required this.padH,
    required this.isDark,
  });

  final CompletedSale sale;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final String dateTimeLine;
  final String? staffCap;
  final double padH;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primaryColor = colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.neutral800,
                  AppColors.neutral700,
                ]
              : [
                  AppColors.successContainer.withValues(alpha: 0.55),
                  AppColors.primaryContainer.withValues(alpha: 0.30),
                  colorScheme.surface,
                ],
          stops: isDark ? null : const [0.0, 0.45, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(padH, 8, padH, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: success badge + close button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Success status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      l10n.tr('sale_completed'),
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip:
                    MaterialLocalizations.of(context).closeButtonTooltip,
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Total amount — hero
          Text(
            _fmtMnt(sale.total),
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 6),

          // Date + time
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                dateTimeLine,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Meta chips row: order ID, staff, payment
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: Icons.tag_rounded,
                label: sale.id,
                colorScheme: colorScheme,
                textTheme: textTheme,
                selectable: true,
              ),
              if (staffCap != null)
                _MetaChip(
                  icon: Icons.person_outline_rounded,
                  label: staffCap!,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              _PaymentChip(
                method: sale.paymentMethod,
                l10n: l10n,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
    this.selectable = false,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final bg = colorScheme.surfaceContainerHighest;
    final fg = colorScheme.onSurfaceVariant;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        if (selectable)
          SelectableText(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
          )
        else
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: content,
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.method,
    required this.l10n,
    required this.colorScheme,
    required this.textTheme,
  });

  final String method;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final label = lang == 'mn'
        ? _labelMn(method)
        : _labelEn(method);
    final (color, bg) = _paymentColors(method, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(method), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _paymentColors(String method, ColorScheme cs) {
    switch (method) {
      case 'cash':
        return (AppColors.success, AppColors.successContainer);
      case 'card':
        return (AppColors.secondary, AppColors.secondaryContainer);
      case 'qpay':
        return (AppColors.tertiary, AppColors.tertiaryContainer);
      case 'account':
        return (AppColors.info, AppColors.infoContainer);
      case 'credit':
        return (AppColors.warning, AppColors.warningContainer);
      default:
        return (cs.primary, cs.primaryContainer);
    }
  }

  IconData _icon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'card':
        return Icons.credit_card_outlined;
      case 'qpay':
        return Icons.qr_code_2_outlined;
      case 'account':
        return Icons.account_balance_outlined;
      case 'credit':
        return Icons.schedule_outlined;
      case 'mobile':
        return Icons.phone_android_outlined;
      default:
        return Icons.payment_outlined;
    }
  }

  String _labelMn(String method) {
    switch (method) {
      case 'cash':
        return 'Бэлэн';
      case 'card':
        return 'Карт';
      case 'qpay':
        return 'QPay';
      case 'account':
        return 'Дансаар';
      case 'credit':
        return 'Зээл';
      case 'mobile':
        return 'Гар утас';
      default:
        return 'Бусад';
    }
  }

  String _labelEn(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'qpay':
        return 'QPay';
      case 'account':
        return 'Bank transfer';
      case 'credit':
        return 'Credit';
      case 'mobile':
        return 'Mobile Pay';
      default:
        return 'Other';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _ProductItemCard extends StatelessWidget {
  const _ProductItemCard({
    required this.item,
    required this.colorScheme,
    required this.textTheme,
  });

  final SaleItem item;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product image with quantity badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AuthenticatedImage(
                  imageUrl: item.product.imageUrl,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: -5,
                bottom: -5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '×${item.quantity}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Name + unit price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtMnt(item.unitPrice)} / нэж',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Line total
          Text(
            _fmtMnt(item.total),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 6.0;
        const dashSpace = 4.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SaleFooter extends StatelessWidget {
  const _SaleFooter({
    required this.sale,
    required this.l10n,
    required this.colorScheme,
    required this.textTheme,
    required this.padH,
    required this.footerBottomInset,
    required this.isDark,
  });

  final CompletedSale sale;
  final AppLocalizations l10n;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final double padH;
  final double footerBottomInset;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      color: isDark
          ? colorScheme.surfaceContainerHighest
          : colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: EdgeInsets.fromLTRB(padH, 14, padH, 14 + footerBottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtotal row
            _PriceRow(
              label: l10n.tr('subtotal'),
              amount: sale.subtotal,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),

            // Discount
            if (sale.discount > 0.009) ...[
              const SizedBox(height: 5),
              _PriceRow(
                label: l10n.tr('discount'),
                amount: -sale.discount,
                colorScheme: colorScheme,
                textTheme: textTheme,
                isDeduction: true,
              ),
            ],

            // VAT
            if (sale.tax > 0.009) ...[
              const SizedBox(height: 5),
              _PriceRow(
                label: l10n.tr('vat'),
                amount: sale.tax,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ],

            // НХАТ
            if (sale.nhhat > 0.009) ...[
              const SizedBox(height: 5),
              _PriceRow(
                label: l10n.tr('nhhat_label'),
                amount: sale.nhhat,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ],

            // Total divider + total row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.tr('total'),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  _fmtMnt(sale.total),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Close button
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
                  'Хаах',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimary,
                    letterSpacing: 0.15,
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

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    required this.colorScheme,
    required this.textTheme,
    this.isDeduction = false,
  });

  final String label;
  final double amount;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isDeduction;

  @override
  Widget build(BuildContext context) {
    final labelColor = colorScheme.onSurfaceVariant;
    final amountColor = isDeduction
        ? AppColors.success
        : colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(color: labelColor),
        ),
        Text(
          isDeduction ? '- ${_fmtMnt(amount.abs())}' : _fmtMnt(amount),
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: amountColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
