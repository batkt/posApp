import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

String _formatMntAmount(double v) {
  return NumberFormat('#,###.##', 'en_US').format(v.round());
}

/// How many of this product are in the current sale (0 = not in cart).
int _saleQtyForProduct(SalesModel sales, String productId) {
  for (final line in sales.currentSaleItems) {
    if (line.product.id == productId) return line.quantity;
  }
  return 0;
}

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

  /// Cashier phone: product step (0) vs cart / payment step (1).
  PageController? _cashierPageController;
  int _cashierMobilePage = 0;

  static const Duration _cashierPageAnim = Duration(milliseconds: 320);
  static const Curve _cashierPageCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    if (widget.cashierMode) {
      _cashierPageController = PageController();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cashierPageController?.dispose();
    super.dispose();
  }

  void _goCashierProductsStep() {
    final c = _cashierPageController;
    if (c == null || !c.hasClients) return;
    c.animateToPage(0, duration: _cashierPageAnim, curve: _cashierPageCurve);
  }

  void _goCashierCheckoutStep() {
    final c = _cashierPageController;
    if (c == null || !c.hasClients) return;
    c.animateToPage(1, duration: _cashierPageAnim, curve: _cashierPageCurve);
  }

  void _openPaymentScreen(BuildContext context) {
    final cashier =
        context.read<AuthModel>().currentUser?.isCashier == true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => cashier
            ? const CashierPaymentScreen()
            : const CheckoutScreen(),
      ),
    );
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
      return _buildCashierMobileTwoStepFlow(context);
    }

    // Flex split avoids fixed 200px cart height (overflowed header + summary + list).
    final gridFlex = widget.cashierMode ? 5 : 3;
    final cartFlex = widget.cashierMode ? 4 : 2;
    return Column(
      children: [
        _buildSearchAndCategories(context),
        Expanded(
          flex: gridFlex,
          child: _buildProductsGrid(
            context,
            gridCrossAxisCount: context.isMobile ? 2 : null,
            gridChildAspectRatio: context.isMobile ? 0.74 : null,
          ),
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

  /// Cashier on phone: 2-column product grid, then cart + totals + pay after "next".
  Widget _buildCashierMobileTwoStepFlow(BuildContext context) {
    final controller = _cashierPageController!;
    return PopScope(
      canPop: _cashierMobilePage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _cashierMobilePage == 1) {
          _goCashierProductsStep();
        }
      },
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: controller,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _cashierMobilePage = i),
              children: [
                Column(
                  children: [
                    _buildSearchAndCategories(context),
                    Expanded(
                      child: _buildProductsGrid(
                        context,
                        gridCrossAxisCount: 2,
                        gridChildAspectRatio: 0.74,
                      ),
                    ),
                  ],
                ),
                _buildCashierMobileCheckoutPage(context),
              ],
            ),
          ),
          if (_cashierMobilePage == 0) _buildCashierMobileProductBar(context),
        ],
      ),
    );
  }

  /// Step 2: line items, totals, and payment (only after user taps next on step 1).
  Widget _buildCashierMobileCheckoutPage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Consumer<SalesModel>(
      builder: (context, sales, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: cs.surface,
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 4,
                  right: 8,
                  top: MediaQuery.paddingOf(context).top > 0 ? 4 : 8,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Бараа руу буцах',
                      onPressed: _goCashierProductsStep,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сагс ба төлбөр',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            sales.isSaleEmpty
                                ? 'Эхлээд бараа сонгоно уу'
                                : '${sales.uniqueSaleItems} төрөл · ${sales.saleItemCount} ширхэг',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!sales.isSaleEmpty)
                      IconButton.filledTonal(
                        tooltip: 'Сагс цэвэрлэх',
                        onPressed: () => sales.clearSale(),
                        icon: Icon(
                          Icons.delete_sweep_rounded,
                          color: cs.error,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              cs.errorContainer.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Expanded(
              child: sales.isSaleEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_basket_outlined,
                              size: 56,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Сагс хоосон',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Бараа нэмсний дараа энд харагдана',
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.tonalIcon(
                              onPressed: _goCashierProductsStep,
                              icon: const Icon(Icons.storefront_rounded),
                              label: const Text('Бараа сонгох'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        for (final item in sales.currentSaleItems)
                          _buildSaleItemTile(context, item, sheetStyle: true),
                      ],
                    ),
            ),
            if (!sales.isSaleEmpty) _buildSheetSaleSummary(context, sales),
          ],
        );
      },
    );
  }

  Widget _buildCashierMobileProductBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      elevation: 8,
      shadowColor: Colors.black38,
      color: cs.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: cs.outlineVariant),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Consumer<SalesModel>(
            builder: (context, sales, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Сагс',
                              style: tt.labelLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sales.isSaleEmpty
                                  ? 'Бараа сонгоно уу'
                                  : '${sales.uniqueSaleItems} төрөл · ${sales.saleItemCount} ширхэг',
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!sales.isSaleEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Нийт',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${_formatMntAmount(sales.total)} ₮',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: sales.isSaleEmpty ? null : _goCashierCheckoutStep,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                    label: const Text(
                      'Дараагийн алхам',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
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
  Widget _buildProductsGrid(
    BuildContext context, {
    int? gridCrossAxisCount,
    double? gridChildAspectRatio,
  }) {
    final crossCount = gridCrossAxisCount ?? context.gridColumns;
    final aspect = gridChildAspectRatio ?? 1.0;

    return Consumer2<InventoryModel, SalesModel>(
      builder: (context, inventory, sales, child) {
        final products = inventory.filteredInventory.where((item) {
          final showAll =
              _selectedCategory == 'Бүгд' || _selectedCategory == 'All';
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
            crossAxisCount: crossCount,
            childAspectRatio: aspect,
            crossAxisSpacing: context.spacing,
            mainAxisSpacing: context.spacing,
          ),
          cacheExtent: 280,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final item = products[index];
            final inSale = _saleQtyForProduct(sales, item.product.id);
            return _ProductCard(
              key: ValueKey(item.product.id),
              item: item,
              inSaleQuantity: inSale,
              onTap: () {
                if (item.currentStock > 0) {
                  sales.addToSale(item.product);
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

  // Sale panel section (split layouts: tablet / desktop / non-cashier mobile).
  Widget _buildSalePanel(BuildContext context) {
    return Consumer<SalesModel>(
      builder: (context, sales, child) {
        return ListView(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          children: _salePanelListChildren(context, sales),
        );
      },
    );
  }

  Widget _buildSaleItemTile(
    BuildContext context,
    SaleItem item, {
    required bool sheetStyle,
  }) {
    final sales = context.read<SalesModel>();
    return _SaleItemTile(
      sheetMode: sheetStyle,
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

  List<Widget> _salePanelListChildren(
    BuildContext context,
    SalesModel sales,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final summaryBlock = _buildClassicSaleSummary(context, sales);

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
                    icon:
                        Icon(Icons.clear, size: context.responsiveIconSize(18)),
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
                'Сагс хоосон',
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
              for (final item in sales.currentSaleItems)
                _buildSaleItemTile(context, item, sheetStyle: false),
            ],
          ),
        ),
      summaryBlock,
    ];
  }

  Widget _buildClassicSaleSummary(BuildContext context, SalesModel sales) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
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
                  : () => _openPaymentScreen(context),
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
  }

  Widget _buildSheetSaleSummary(BuildContext context, SalesModel sales) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Material(
        color: cs.surfaceContainerLow,
        elevation: 0,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Тооцоо',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 12),
              _sheetSummaryLine(context, 'Дэд дүн', sales.subtotal, false),
              const SizedBox(height: 8),
              _sheetSummaryLine(context, 'НӨАТ (10%)', sales.tax, false),
              const SizedBox(height: 12),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Нийт төлөх',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    '${_formatMntAmount(sales.total)} ₮',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      fontSize: 22,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: sales.isSaleEmpty
                    ? null
                    : () => _openPaymentScreen(context),
                icon: const Icon(Icons.payments_rounded, size: 22),
                label: const Text(
                  'Төлбөр төлөх',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetSummaryLine(
    BuildContext context,
    String label,
    double amount,
    bool emphasize,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '${_formatMntAmount(amount)} ₮',
          style: tt.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
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
  /// Units of this SKU in the active sale (drives border + badge).
  final int inSaleQuantity;

  const _ProductCard({
    super.key,
    required this.item,
    required this.onTap,
    this.inSaleQuantity = 0,
  });

  static const Color _stockPlentyGreen = Color(0xFF16A34A);
  static const Color _stockLowRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final inCart = inSaleQuantity > 0;
    final multiInCart = inSaleQuantity >= 2;
    final stock = item.currentStock;
    final stockHealthy = stock > 20;
    final stockColor = stockHealthy ? _stockPlentyGreen : _stockLowRed;

    final borderColor = inCart ? colorScheme.primary : colorScheme.outlineVariant;
    final borderWidth = inCart ? 2.5 : 1.0;

    return Material(
      color: inCart
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.isOutOfStock ? null : onTap,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: colorScheme.primary.withValues(alpha: 0.06),
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
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (item.isOutOfStock)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: Text(
                        'ДУУССАН',
                        style: textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  if (inCart)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 22,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  if (inCart)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: multiInCart ? 10 : 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: multiInCart
                              ? colorScheme.primary
                              : colorScheme.primary.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white,
                            width: multiInCart ? 2 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '×$inSaleQuantity',
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: multiInCart ? 15 : 13,
                            height: 1,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                10,
                8,
                10,
                context.spacing * 0.5 + 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: context.responsiveFontSize(11),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.product.code != null ||
                      item.product.barCode != null) ...[
                    SizedBox(height: context.spacing * 0.2),
                    Text(
                      item.product.code ?? item.product.barCode ?? '',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: context.responsiveFontSize(9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: context.spacing * 0.35),
                  Row(
                    children: [
                      Text(
                        'Үлдэгдэл: ',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: context.responsiveFontSize(9),
                        ),
                      ),
                      Text(
                        '$stock',
                        style: textTheme.labelMedium?.copyWith(
                          color: stockColor,
                          fontWeight: FontWeight.w800,
                          fontSize: context.responsiveFontSize(10),
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.spacing * 0.25),
                  Text(
                    '${_formatMntAmount(item.product.price)} ₮',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: context.responsiveFontSize(11),
                      fontFeatures: const [FontFeature.tabularFigures()],
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
  const _SaleItemTile({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    this.sheetMode = false,
  });

  final SaleItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final bool sheetMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final lineTotal = item.unitPrice * item.quantity;

    if (!sheetMode) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surface,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AuthenticatedImage(
                  imageUrl: item.product.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatMntAmount(item.unitPrice)} ₮ × ${item.quantity}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatMntAmount(lineTotal)} ₮',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: onDecrement,
                          icon: Icon(
                            Icons.remove_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${item.quantity}',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: onIncrement,
                          icon: Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Хасах',
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 22,
                      color: colorScheme.error,
                    ),
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
