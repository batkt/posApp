import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/inventory_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../widgets/authenticated_image.dart';
import '../../widgets/barcode_scan_sheet.dart';
import 'baraa_detail_screen.dart';
import 'low_stock_baraa_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.showAppBar = true});

  /// False when shown inside [MainScreen] (shell already shows [inventory]).
  final bool showAppBar;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcodeToSearch(BuildContext context) async {
    final code = await showBarcodeScanSheet(context);
    final v = code?.trim();
    if (v == null || v.isEmpty) return;
    if (!context.mounted) return;
    _searchController.text = v;
    context.read<InventoryModel>().setSearchQuery(v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Барааны менежмент'),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddProductDialog(context),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!widget.showAppBar)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Бараа нэмэх',
                icon: const Icon(Icons.add),
                onPressed: () => _showAddProductDialog(context),
              ),
            ),
          // Search & Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {});
                    context.read<InventoryModel>().setSearchQuery(value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Нэр эсвэл кодоор хайх...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Баркод унших',
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          onPressed: () => _scanBarcodeToSearch(context),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context
                                  .read<InventoryModel>()
                                  .setSearchQuery('');
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Consumer<InventoryModel>(
                  builder: (context, inventory, child) {
                    return SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: inventory.categories.length,
                        itemBuilder: (context, index) {
                          final category = inventory.categories[index];
                          final isSelected =
                              inventory.selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: isSelected,
                              onSelected: (_) =>
                                  inventory.setCategory(category),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Inventory Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer<InventoryModel>(
              builder: (context, inventory, child) {
                return Row(
                  children: [
                    _StatChip(
                      label: 'Нийт бүтээгдэхүүн',
                      value: '${inventory.totalStockCount}',
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Цөөн үлдсэн',
                      value: '${inventory.lowStockCount}',
                      color: inventory.lowStockCount > 0
                          ? AppColors.warning
                          : colorScheme.outline,
                      onTap: inventory.lowStockCount > 0
                          ? () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const LowStockBaraaScreen(),
                                ),
                              );
                            }
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Inventory List
          Expanded(
            child: Consumer<InventoryModel>(
              builder: (context, inventory, child) {
                final items = inventory.filteredInventory;

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Бүтээгдэхүүн олдсонгүй',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _InventoryItemTile(
                      item: item,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BaraaDetailScreen(item: item),
                        ),
                      ),
                      onRestock: () => _showRestockDialog(context, item),
                      onEdit: () => _showEditProductDialog(context, item),
                      onDelete: () => _showDeleteConfirmation(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Шинэ бүтээгдэхүүн нэмэх'),
        content: const Text('Бүтээгдэхүүн үүсгэх маягт энд байна'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Нэмэх'),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(BuildContext context, InventoryItem item) {
    final quantityController = TextEditingController();

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
              final quantity =
                  int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                context
                    .read<InventoryModel>()
                    .restock(item.product.id, quantity);
              }
              Navigator.pop(context);
            },
            child: const Text('Нөхөн дүүргэх'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, InventoryItem item) {
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

  void _showDeleteConfirmation(BuildContext context, InventoryItem item) {
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
              context
                  .read<InventoryModel>()
                  .deleteProduct(item.product.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
  }
}

// ─── Stat chip ───────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}

// ─── Inventory item tile ──────────────────────────────────────────────────────

class _InventoryItemTile extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final VoidCallback onRestock;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InventoryItemTile({
    required this.item,
    required this.onTap,
    required this.onRestock,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final product = item.product;

    Color stockColor;
    if (item.isOutOfStock) {
      stockColor = AppColors.error;
    } else if (item.isLowStock) {
      stockColor = AppColors.warning;
    } else {
      stockColor = AppColors.success;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          // Reduced vertical padding for compact height
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Product Image (smaller)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AuthenticatedImage(
                  imageUrl: product.imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // Product Info — name takes all available space (no ID)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title — up to 2 lines
                    Text(
                      product.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Price with ₮ sign — bottom right of the info column
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Үлдэгдэл badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stockColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Үлдэгдэл: ${item.currentStock}',
                            style: textTheme.labelSmall?.copyWith(
                              color: stockColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // ₮ Price — bottom right
                        Text(
                          MntAmountFormatter.formatTugrik(product.price),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Actions menu (no separate stock chip — merged above)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'restock':
                      onRestock();
                      break;
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
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
                      Icon(Icons.delete_outline,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text('Устгах',
                          style: TextStyle(color: AppColors.error)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
