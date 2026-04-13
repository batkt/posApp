import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_model.dart';
import '../models/sales_model.dart';
import '../models/inventory_model.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';
import '../utils/mongolian_date_formatter.dart';
import 'cashier_payment_screen.dart';
import 'checkout_screen.dart';
import '../widgets/test_image_widget.dart';
import '../widgets/authenticated_image.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key, this.cashierMode = false});

  /// When true, embedded under [CashierMainScreen] (no scaffold) and cashier payment UI.
  final bool cashierMode;

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Бүгд';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = ResponsiveHelper.buildResponsive(
      context: context,
      mobile: _buildMobileLayout(context),
      tablet: _buildTabletLayout(context),
      desktop: _buildDesktopLayout(context),
      posDevice: _buildPosLayout(context),
    );

    if (widget.cashierMode) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Борлуулалтын цэг',
              style: TextStyle(
                fontSize: context.responsiveFontSize(20),
              ),
            ),
            Text(
              MongolianDateFormatter.formatDate(DateTime.now()),
              style: TextStyle(
                fontSize: context.responsiveFontSize(12),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.bug_report,
              size: context.responsiveIconSize(24),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TestImageWidget(),
                ),
              );
            },
            tooltip: 'Test Images',
          ),
          if (context.isPosDevice)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.desktop_windows,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      ),
      body: content,
    );
  }

  // Mobile layout - single column, optimized for phones
  Widget _buildMobileLayout(BuildContext context) {
    if (widget.cashierMode && ResponsiveHelper.isMobile(context)) {
      return _buildCashierMobileDraggableSheet(context);
    }

    // Flex split avoids fixed 200px cart height (overflowed header + summary + list).
    final gridFlex = widget.cashierMode ? 5 : 3;
    final cartFlex = widget.cashierMode ? 4 : 2;
    return Column(
      children: [
        _buildSearchAndCategories(context),
        Expanded(
          flex: gridFlex,
          child: _buildProductsGrid(context),
        ),
        Expanded(
          flex: cartFlex,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: _buildSalePanel(context),
          ),
        ),
      ],
    );
  }

  /// Cashier on phone: full-width product grid + swipeable bottom sheet for cart.
  Widget _buildCashierMobileDraggableSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            _buildSearchAndCategories(context),
            Expanded(child: _buildProductsGrid(context)),
          ],
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.22,
          minChildSize: 0.12,
          maxChildSize: 0.92,
          snap: true,
          snapSizes: const [0.12, 0.38, 0.92],
          builder: (context, scrollController) {
            return Material(
              color: colorScheme.surfaceContainerHighest,
              elevation: 6,
              shadowColor: Colors.black38,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: _buildSalePanel(context, sheetScrollController: scrollController),
            );
          },
        ),
      ],
    );
  }

  // Tablet layout - side by side
  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        // Products panel - 70% width
        Expanded(
          flex: 7,
          child: Column(
            children: [
              _buildSearchAndCategories(context),
              Expanded(child: _buildProductsGrid(context)),
            ],
          ),
        ),
        // Sale panel - 30% width
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: _buildSalePanel(context),
          ),
        ),
      ],
    );
  }

  // Desktop layout - larger side by side
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Products panel - 65% width
        Expanded(
          flex: 13,
          child: Column(
            children: [
              _buildSearchAndCategories(context),
              Expanded(child: _buildProductsGrid(context)),
            ],
          ),
        ),
        // Sale panel - 35% width
        Expanded(
          flex: 7,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: _buildSalePanel(context),
          ),
        ),
      ],
    );
  }

  // POS Device layout - optimized for large screens
  Widget _buildPosLayout(BuildContext context) {
    return Row(
      children: [
        // Products panel - 60% width
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildSearchAndCategories(context),
              Expanded(child: _buildProductsGrid(context)),
            ],
          ),
        ),
        // Sale panel - 40% width
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: _buildSalePanel(context),
          ),
        ),
      ],
    );
  }

  // Search and categories section
  Widget _buildSearchAndCategories(BuildContext context) {
    return Padding(
      padding: context.responsivePadding,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Бүтээгдэхүүн хайх...',
              prefixIcon:
                  Icon(Icons.search, size: context.responsiveIconSize(24)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          size: context.responsiveIconSize(20)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
          SizedBox(height: context.spacing),
          SizedBox(
            height: context.isMobile ? 36 : 40,
            child: Consumer<InventoryModel>(
              builder: (context, inventory, child) {
                return Row(
                  children: [
                    // "View All" button
                    Padding(
                      padding: EdgeInsets.only(right: context.spacing * 0.5),
                      child: FilterChip(
                        label: Text(
                          'Бүгдийг харах',
                          style: TextStyle(
                            fontSize: context.responsiveFontSize(12),
                          ),
                        ),
                        selected: _selectedCategory == 'Бүгд',
                        onSelected: (selected) {
                          setState(() => _selectedCategory = 'Бүгд');
                        },
                      ),
                    ),
                    // Category chips
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: inventory.categories.length > 1
                            ? inventory.categories.length - 1
                            : 0,
                        itemBuilder: (context, index) {
                          final category = inventory.categories[index + 1];
                          final isSelected = _selectedCategory == category;
                          return Padding(
                            padding:
                                EdgeInsets.only(right: context.spacing * 0.5),
                            child: FilterChip(
                              label: Text(
                                category,
                                style: TextStyle(
                                  fontSize: context.responsiveFontSize(12),
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() => _selectedCategory = category);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Products grid section
  Widget _buildProductsGrid(BuildContext context) {
    return Consumer<InventoryModel>(
      builder: (context, inventory, child) {
        final products = inventory.filteredInventory.where((item) {
          final showAll = _selectedCategory == 'Бүгд' ||
              _selectedCategory == 'All';
          final matchesCategory = showAll ||
              item.product.angilal?.contains(_selectedCategory) == true ||
              item.product.category == _selectedCategory;
          final matchesSearch = _searchQuery.isEmpty ||
              item.product.name
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              item.product.code
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ==
                  true ||
              item.product.barCode
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ==
                  true;
          return matchesCategory && matchesSearch;
        }).toList();

        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: context.responsiveIconSize(64),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: context.spacing),
                Text(
                  'Бүтээгдэхүүн олдсонгүй',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: context.responsiveFontSize(16),
                      ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: context.responsivePadding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: context.gridColumns,
            childAspectRatio:
                1.0, // Fixed aspect ratio for consistent card sizes
            crossAxisSpacing: context.spacing,
            mainAxisSpacing: context.spacing,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final item = products[index];
            return _ProductCard(
              item: item,
              onTap: () {
                if (item.currentStock > 0) {
                  context.read<SalesModel>().addToSale(item.product);
                  inventory.deductStock(item.product.id, 1);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Бүтээгдэхүүн дууссан'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  // Sale panel section
  Widget _buildSalePanel(
    BuildContext context, {
    ScrollController? sheetScrollController,
  }) {
    return Consumer<SalesModel>(
      builder: (context, sales, child) {
        final colorScheme = Theme.of(context).colorScheme;

        final children = <Widget>[
          if (sheetScrollController != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ..._salePanelListChildren(context, sales),
        ];

        return ListView(
          controller: sheetScrollController,
          padding: EdgeInsets.zero,
          physics: sheetScrollController != null
              ? const AlwaysScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          children: children,
        );
      },
    );
  }

  List<Widget> _salePanelListChildren(BuildContext context, SalesModel sales) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget saleTile(SaleItem item) {
      return _SaleItemTile(
        item: item,
        onIncrement: () {
          final inventory = context.read<InventoryModel>();
          inventory.deductStock(item.product.id, 1);
          sales.incrementSaleQuantity(item.product.id);
        },
        onDecrement: () {
          if (item.quantity > 1) {
            final inventory = context.read<InventoryModel>();
            inventory.restock(item.product.id, 1);
            sales.decrementSaleQuantity(item.product.id);
          }
        },
        onRemove: () {
          final inventory = context.read<InventoryModel>();
          sales.removeFromSale(item.product.id);
          inventory.restock(item.product.id, item.quantity);
        },
      );
    }

    final summaryBlock = Container(
      padding: context.responsivePadding,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryRow(
            context: context,
            label: 'Дүн',
            amount: sales.subtotal,
            isTotal: false,
          ),
          SizedBox(height: context.spacing * 0.5),
          _buildSummaryRow(
            context: context,
            label: 'НӨАТ',
            amount: sales.tax,
            isTotal: false,
          ),
          SizedBox(height: context.spacing * 0.5),
          _buildSummaryRow(
            context: context,
            label: 'Нийт',
            amount: sales.total,
            isTotal: true,
          ),
          SizedBox(height: context.spacing),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: sales.isSaleEmpty
                  ? null
                  : () {
                      final cashier =
                          context.read<AuthModel>().currentUser?.isCashier ==
                              true;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => cashier
                              ? const CashierPaymentScreen()
                              : const CheckoutScreen(),
                        ),
                      );
                    },
              icon: Icon(Icons.payment, size: context.responsiveIconSize(20)),
              label: Text(
                'Төлөх',
                style: TextStyle(fontSize: context.responsiveFontSize(16)),
              ),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: context.spacing * 0.75),
              ),
            ),
          ),
        ],
      ),
    );

    return [
      Container(
        padding: context.responsivePadding,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Одоогийн борлуулалт',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: context.responsiveFontSize(18),
                    ),
                  ),
                ),
                if (!sales.isSaleEmpty)
                  TextButton.icon(
                    onPressed: () => sales.clearSale(),
                    icon: Icon(Icons.clear,
                        size: context.responsiveIconSize(18)),
                    label: Text(
                      'Цэвэрлэх',
                      style:
                          TextStyle(fontSize: context.responsiveFontSize(14)),
                    ),
                  ),
              ],
            ),
            SizedBox(height: context.spacing * 0.5),
            Text(
              sales.saleItemCount == 0
                  ? 'Бүтээгдэхүүн нэмээгүй'
                  : '${sales.saleItemCount} бүтээгдэхүүн',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: context.responsiveFontSize(14),
              ),
            ),
          ],
        ),
      ),
      if (sales.isSaleEmpty)
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.spacing * 2,
            horizontal: context.spacing,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: context.responsiveIconSize(48),
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: context.spacing),
              Text(
                'Сагланг хоосон',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: context.responsiveFontSize(16),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
      else
        Padding(
          padding: EdgeInsets.all(context.spacing),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in sales.currentSaleItems) saleTile(item),
            ],
          ),
        ),
      summaryBlock,
    ];
  }

  Widget _buildSummaryRow({
    required BuildContext context,
    required String label,
    required double amount,
    required bool isTotal,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: context.responsiveFontSize(16),
                )
              : textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: context.responsiveFontSize(14),
                ),
        ),
        Text(
          'MNT ${amount.toStringAsFixed(0)}',
          style: isTotal
              ? textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                  fontSize: context.responsiveFontSize(18),
                )
              : textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: context.responsiveFontSize(14),
                ),
        ),
      ],
    );
  }

  // Get search query
  String get _searchQuery => _searchController.text.trim();
}

class _ProductCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onTap;

  const _ProductCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.isOutOfStock ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AuthenticatedImage(
                    imageUrl: item.product.imageUrl,
                    fit: BoxFit.cover,
                  ),
                  if (item.isOutOfStock)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          'ДУУССАН',
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (item.isLowStock && !item.isOutOfStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.currentStock} үлдсэн',
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.spacing * 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name with responsive text
                  Text(
                    item.product.name,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: context.responsiveFontSize(10),
                    ),
                    maxLines: context.isMobile ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.spacing * 0.25),
                  // Product code/barcode if available
                  if (item.product.code != null || item.product.barCode != null)
                    Text(
                      item.product.code ?? item.product.barCode ?? '',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: context.responsiveFontSize(8),
                      ),
                    ),
                  // Stock info
                  Text(
                    'Stock: ${item.currentStock}',
                    style: textTheme.labelSmall?.copyWith(
                      color: item.isLowStock
                          ? AppColors.warning
                          : colorScheme.onSurfaceVariant,
                      fontSize: context.responsiveFontSize(8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: context.spacing * 0.25),
                  // Price with responsive text
                  Text(
                    'MNT ${item.product.price.toStringAsFixed(0)}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: context.responsiveFontSize(10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleItemTile extends StatelessWidget {
  final SaleItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _SaleItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AuthenticatedImage(
              imageUrl: item.product.imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MNT ${item.product.price.toStringAsFixed(0)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Quantity Controls
          Row(
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 20,
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 20,
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                iconSize: 20,
                color: colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
