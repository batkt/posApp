import 'package:flutter/material.dart';
import '../../models/inventory_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';
import '../../widgets/authenticated_image.dart';

class BaraaDetailScreen extends StatelessWidget {
  final InventoryItem item;

  const BaraaDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final product = item.product;

    Color stockColor;
    String stockLabel;
    if (item.isOutOfStock) {
      stockColor = AppColors.error;
      stockLabel = 'Дууссан';
    } else if (item.isLowStock) {
      stockColor = AppColors.warning;
      stockLabel = 'Цөөн үлдсэн';
    } else {
      stockColor = AppColors.success;
      stockLabel = 'Бэлэн байна';
    }

    final categoryLabel = product.category.trim().isNotEmpty
        ? product.category
        : (product.angilal?.trim().isNotEmpty == true
            ? product.angilal!.trim()
            : '—');
    final hasImage = product.imageUrl.trim().isNotEmpty;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            foregroundColor: colorScheme.onSurface,
            leading: Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor:
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
                ),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    AuthenticatedImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                    )
                  else
                    ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 72,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.shadow.withValues(alpha: 0.18),
                          Colors.transparent,
                          colorScheme.shadow.withValues(alpha: 0.5),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Барааны мэдээлэл',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (categoryLabel != '—')
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            Icons.label_outline,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          label: Text(categoryLabel),
                          side: BorderSide(color: colorScheme.outlineVariant),
                          backgroundColor:
                              colorScheme.primaryContainer.withValues(alpha: 0.35),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (product.code != null && product.code!.isNotEmpty)
                        _MetaPill(
                          icon: Icons.qr_code_2_rounded,
                          label: 'Код',
                          value: product.code!,
                        ),
                      if (product.barCode != null && product.barCode!.isNotEmpty)
                        _MetaPill(
                          icon: Icons.barcode_reader,
                          label: 'Баркод',
                          value: product.barCode!,
                        ),
                      _MetaPill(
                        icon: Icons.straighten_rounded,
                        label: 'Нэгж',
                        value: product.khemjikhNegj ?? product.unitLabel,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              MntAmountFormatter.formatTugrik(product.price),
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          if (product.urtugUne != null && product.urtugUne! > 0)
                            Expanded(
                              child: Text(
                                'Өртөг: ${MntAmountFormatter.formatTugrik(product.urtugUne!)}',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: stockColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: stockColor.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          item.isOutOfStock
                              ? Icons.remove_circle_outline
                              : item.isLowStock
                                  ? Icons.warning_amber_outlined
                                  : Icons.check_circle_outline,
                          color: stockColor,
                          size: 30,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stockLabel,
                                style: textTheme.titleSmall?.copyWith(
                                  color: stockColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Үлдэгдэл: ${item.currentStock} ${product.posStockQuantitySuffix}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (product.boxPiecesPerBoxHint != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  product.boxPiecesPerBoxHint!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${item.currentStock}',
                            style: textTheme.displaySmall?.copyWith(
                              color: stockColor,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _DetailCard(
                    children: [
                      _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Ангилал',
                        value: categoryLabel,
                      ),
                      if (product.angilal != null &&
                          product.angilal!.trim().isNotEmpty &&
                          product.angilal!.trim() != product.category.trim())
                        _DetailRow(
                          icon: Icons.folder_outlined,
                          label: 'Төрөл / ангилал',
                          value: product.angilal!.trim(),
                        ),
                      _DetailRow(
                        icon: Icons.straighten_outlined,
                        label: 'Хэмжих нэгж',
                        value: product.khemjikhNegj ?? product.unitLabel,
                      ),
                      if (product.isBoxSaleUnit) ...[
                        _DetailRow(
                          icon: Icons.inventory_outlined,
                          label: 'Хайрцаглах',
                          value: 'Тийм',
                        ),
                        if (product.negKhairtsaganDahiShirhegiinToo != null &&
                            product.negKhairtsaganDahiShirhegiinToo! > 0)
                          _DetailRow(
                            icon: Icons.apps_outlined,
                            label: 'Нэг хайрцаг дахь ширхэг',
                            value: '${product.negKhairtsaganDahiShirhegiinToo} ш',
                          ),
                      ],
                      _DetailRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Хамгийн бага нөөц',
                        value: '${item.minStockLevel}',
                      ),
                      if (item.lastRestocked != null)
                        _DetailRow(
                          icon: Icons.update,
                          label: 'Сүүлд нөхсөн',
                          value: MongolianDateFormatter.formatShortDate(
                            item.lastRestocked!,
                          ),
                        ),
                      if (product.noatBodohEsekh == true)
                        _DetailRow(
                          icon: Icons.receipt_long_outlined,
                          label: 'НӨАТ',
                          value: product.noatiinDun != null
                              ? MntAmountFormatter.formatTugrik(product.noatiinDun!)
                              : 'Тийм',
                        ),
                    ],
                  ),

                  SizedBox(height: 16 + bottomPad),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final nonEmpty = children.whereType<_DetailRow>().toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Text(
              'Дэлгэрэнгүй мэдээлэл',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: colorScheme.primary,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: colorScheme.outlineVariant.withValues(alpha: 0.65),
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: colorScheme.primary),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.38,
                ),
                child: Text(
                  label,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: SelectableText(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.end,
                maxLines: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
