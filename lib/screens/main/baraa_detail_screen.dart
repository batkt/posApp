import 'package:flutter/material.dart';
import '../../models/inventory_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 268,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8, top: 8),
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor:
                      colorScheme.surface.withValues(alpha: 0.92),
                  foregroundColor: colorScheme.onSurface,
                ),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              ),
            ),
            actions: const [],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AuthenticatedImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.shadow.withValues(alpha: 0.22),
                          Colors.transparent,
                          colorScheme.shadow.withValues(alpha: 0.55),
                        ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width - 88,
                        ),
                        child: Text(
                          product.name,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          product.category,
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

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

                  const SizedBox(height: 18),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        MntAmountFormatter.formatTugrik(product.price),
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (product.urtugUne != null &&
                          product.urtugUne! > 0) ...[
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Өртөг: ${MntAmountFormatter.formatTugrik(product.urtugUne!)}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: stockColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: stockColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.isOutOfStock
                              ? Icons.remove_circle_outline
                              : item.isLowStock
                                  ? Icons.warning_amber_outlined
                                  : Icons.check_circle_outline,
                          color: stockColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stockLabel,
                              style: textTheme.titleSmall?.copyWith(
                                color: stockColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Үлдэгдэл: ${item.currentStock} ${product.khemjikhNegj ?? product.unitLabel}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Big stock number
                        Text(
                          '${item.currentStock}',
                          style: textTheme.displaySmall?.copyWith(
                            color: stockColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _DetailCard(children: [
                    if (product.code != null && product.code!.isNotEmpty)
                      _DetailRow(
                        icon: Icons.qr_code,
                        label: 'Код',
                        value: product.code!,
                      ),
                    if (product.barCode != null && product.barCode!.isNotEmpty)
                      _DetailRow(
                        icon: Icons.barcode_reader,
                        label: 'Баркод',
                        value: product.barCode!,
                      ),
                    _DetailRow(
                      icon: Icons.category_outlined,
                      label: 'Ангилал',
                      value: product.category,
                    ),
                    _DetailRow(
                      icon: Icons.straighten_outlined,
                      label: 'Хэмжих нэгж',
                      value: product.khemjikhNegj ?? product.unitLabel,
                    ),
                    _DetailRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Хамгийн бага нөөц',
                      value: '${item.minStockLevel}',
                    ),
                    if (item.lastRestocked != null)
                      _DetailRow(
                        icon: Icons.update,
                        label: 'Сүүлд нөхсөн',
                        value: _formatDate(item.lastRestocked!),
                      ),
                    if (product.noatBodohEsekh == true)
                      _DetailRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'НӨАТ',
                        value: product.noatiinDun != null
                            ? MntAmountFormatter.formatTugrik(product.noatiinDun!)
                            : 'Тийм',
                      ),
                  ]),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
        color: colorScheme.surface,
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
              child: Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                maxLines: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
