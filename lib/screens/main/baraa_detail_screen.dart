import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.more_vert_rounded,
                      color: colorScheme.onSurface,
                    ),
                  ),
                onSelected: (value) {
                  if (value == 'restock') {
                    _showRestockDialog(context, item);
                  } else if (value == 'edit') {
                    _showEditDialog(context, item);
                  } else if (value == 'delete') {
                    _showDeleteDialog(context, item);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'restock',
                    child: Row(children: [
                      Icon(Icons.add_box_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Нөхөн дүүргэх'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Засах'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text('Устгах', style: TextStyle(color: AppColors.error)),
                    ]),
                  ),
                ],
              ),
              ),
            ],
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showRestockDialog(context, item),
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('Нөхөн дүүргэх'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _showEditDialog(context, item),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Засах'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
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

  void _showRestockDialog(BuildContext context, InventoryItem item) {
    final quantityController = TextEditingController(text: '10');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.product.name} нөхөн дүүргэх'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Одоогийн үлдэгдэл: ${item.currentStock}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Нэмэх тоо хэмжээ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text) ?? 0;
              if (qty > 0) {
                context.read<InventoryModel>().restock(item.product.id, qty);
              }
              Navigator.pop(context);
            },
            child: const Text('Нөхөн дүүргэх'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.product.name} засварлах'),
        content: const Text('Бүтээгдэхүүн засварлах маягт энд байна'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Өөрчлөлт хадгалах'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Бүтээгдэхүүн устгах уу?'),
        content: Text(
            '"${item.product.name}" бүтээгдэхүүнийг устгахдаа итгэлтэй байна уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () {
              context.read<InventoryModel>().deleteProduct(item.product.id);
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to list
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Устгах'),
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
