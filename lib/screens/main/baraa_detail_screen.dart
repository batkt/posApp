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
          // Hero image AppBar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: AuthenticatedImage(
                imageUrl: product.imageUrl,
                fit: BoxFit.cover,
              ),
            ),
            actions: [
              // Menu actions
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withOpacity(0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert),
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
              const SizedBox(width: 8),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + category badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product.category,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Price row
                  Row(
                    children: [
                      Text(
                        MntAmountFormatter.formatTugrik(product.price),
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (product.urtugUne != null &&
                          product.urtugUne! > 0) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Өртөг: ${MntAmountFormatter.formatTugrik(product.urtugUne!)}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Stock status card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: stockColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: stockColor.withOpacity(0.3),
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

                  // Details section
                  Text(
                    'Дэлгэрэнгүй мэдээлэл',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

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
    final nonEmpty = children.whereType<_DetailRow>().toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: 48,
                color: colorScheme.outlineVariant.withOpacity(0.5),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
