import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/auth_model.dart';
import '../../models/locale_model.dart';
import '../../models/sales_model.dart';
import '../../models/inventory_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/mongolian_date_formatter.dart';
import '../../utils/uramshuulal_helper.dart';
import 'cashier_payment_screen.dart';
import '../main/checkout_screen.dart';
import '../../widgets/barcode_scan_sheet.dart';
import '../../widgets/test_image_widget.dart';
import '../../widgets/authenticated_image.dart';
import '../../services/terminal_tulbur_signal_service.dart';

/// How many of this product are in the current sale (0 = not in cart).
int _saleQtyForProduct(SalesModel sales, String productId) {
  for (final line in sales.currentSaleItems) {
    if (line.product.id == productId) return line.quantity;
  }
  return 0;
}

class POSScreen extends StatefulWidget {
  const POSScreen({
    super.key,
    this.cashierMode = false,
    this.mobileStaffMode = false,
  });

  /// When true, embedded under kiosk [CashierMainScreen] or mobile [MobilePosMainScreen] (no scaffold).
  final bool cashierMode;

  /// `/khyanalt/mobile` staff only: two-step layout (same UniPOS card flow as kiosk).
  final bool mobileStaffMode;

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Бүгд';

  /// Cashier phone: product step (0) vs cart / payment step (1).
  PageController? _cashierPageController;
  int _cashierMobilePage = 0;
  int _appliedCashierReturnEpoch = 0;

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

  String _staffCartPaymentBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return l10n.tr(
      widget.mobileStaffMode
          ? 'staff_mobile_cart_payment_banner'
          : 'staff_kiosk_cart_payment_banner',
    );
  }

  String _staffSalePanelTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!widget.cashierMode) return l10n.tr('current_sale');
    return widget.mobileStaffMode
        ? l10n.tr('current_sale')
        : l10n.tr('staff_kiosk_sale_panel_title');
  }

  String _staffCartChipLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return widget.mobileStaffMode
        ? l10n.tr('pos')
        : l10n.tr('staff_kiosk_cart_chip');
  }

  void _clearSaleAndRestock(BuildContext context, SalesModel sales) {
    final inventory = context.read<InventoryModel>();
    for (final line in sales.currentSaleItems) {
      inventory.restock(line.product.id, line.quantity);
    }
    sales.clearSale();
  }

  void _showBulkPricingSheet(BuildContext context, SaleItem item) {
    final l10n = AppLocalizations.of(context);
    final p = item.product;
    if (p.buuniiUneEsekh != true || p.buuniiUneJagsaalt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.tr('pos_sale_no_bulk'))),
      );
      return;
    }
    final tiers = List<Map<String, dynamic>>.from(p.buuniiUneJagsaalt)
      ..sort(
        (a, b) => ((a['buuniiToo'] as num?) ?? 0).compareTo(
              (b['buuniiToo'] as num?) ?? 0,
            ),
      );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    l10n.tr('pos_sale_bulk_sheet_title'),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_motion_outlined),
                  title: Text(l10n.tr('pos_sale_auto_bulk')),
                  onTap: () {
                    ctx.read<SalesModel>().useAutomaticWholesaleForProduct(
                          item.product.id,
                        );
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(l10n.tr('pos_sale_retail')),
                  onTap: () {
                    ctx.read<SalesModel>().applyRetailUnitForLine(item.product.id);
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(height: 1),
                for (final t in tiers)
                  ListTile(
                    leading: const Icon(Icons.layers_outlined),
                    title: Text(
                      '≥ ${t['buuniiToo']} — ${MntAmountFormatter.format((t['buuniiUne'] as num?)?.toDouble() ?? 0)} ₮',
                    ),
                    onTap: () {
                      final u = (t['buuniiUne'] as num?)?.toDouble() ?? 0;
                      ctx.read<SalesModel>().applyWholesaleTierUnit(
                            item.product.id,
                            u,
                          );
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPromotionSheet(BuildContext context, SaleItem item) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final active = UramshuulalHelper.activePromotions(item.product.uramshuulal, now);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    l10n.tr('pos_sale_promo_sheet_title'),
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (item.uramshuulaliinId != null)
                  ListTile(
                    leading: Icon(Icons.clear_all, color: Theme.of(ctx).colorScheme.error),
                    title: Text(l10n.tr('pos_sale_clear_promo')),
                    onTap: () {
                      ctx.read<SalesModel>().setLineUramshuulal(item.product.id, null);
                      Navigator.pop(ctx);
                    },
                  ),
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Text(
                      l10n.tr('pos_sale_no_active_promos'),
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  for (final r in active)
                    ListTile(
                      leading: const Icon(Icons.local_offer_outlined),
                      title: Text(r['ner']?.toString() ?? '—'),
                      trailing:
                          item.uramshuulaliinId == UramshuulalHelper.promotionPickId(r)
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(ctx).colorScheme.primary,
                                )
                              : null,
                      onTap: () {
                        final id = UramshuulalHelper.promotionPickId(r);
                        ctx.read<SalesModel>().setLineUramshuulal(
                              item.product.id,
                              id,
                            );
                        Navigator.pop(ctx);
                      },
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPaymentScreen(BuildContext context) {
    final auth = context.read<AuthModel>();
    final cashier = auth.currentUser?.isCashier == true;
    final useCashierPayment =
        cashier || widget.cashierMode || auth.staffAccess.allowsMobile;
    final mobileQpayMode =
        widget.mobileStaffMode || auth.staffAccess.allowsMobile;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => useCashierPayment
            ? CashierPaymentScreen(
                terminalMode: mobileQpayMode
                    ? CashierTerminalPaymentMode.qpayOnly
                    : CashierTerminalPaymentMode.cardOnly,
              )
            : const CheckoutScreen(),
      ),
    );
  }

  Future<void> _scanBarcodeToSearch(BuildContext context) async {
    final code = await showBarcodeScanSheet(context);
    final v = code?.trim();
    if (v == null || v.isEmpty) return;
    if (!context.mounted) return;
    _searchController.text = v;
    setState(() {});
  }

  /// Mobile staff → posBack → kiosk polls and can open UniPOS for this amount.
  Future<void> _sendTerminalCardSignal(
    BuildContext context,
    SalesModel sales,
  ) async {
    final l10n = AppLocalizations.of(context);
    final auth = context.read<AuthModel>();
    if (!auth.canSubmitPosSales || !auth.staffAccess.allowsMobile) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tr('terminal_signal_failed')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final session = auth.posSession!;
    try {
      await TerminalTulburSignalService().createRequest(
        salbariinId: session.salbariinId,
        amountMnt: sales.total,
        tailbar:
            '${sales.uniqueSaleItems} төрөл · ${sales.saleItemCount} ширхэг',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('terminal_signal_sent')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on TerminalTulburSignalException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.tr('terminal_signal_failed')}: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Two-step PageView (products → cart/pay): mobile staff always; kiosk only on narrow width.
    // After receipt, [ReceiptScreen] bumps [cashierReturnToProductsEpoch] — must animate to page 0 for both.
    final cashierMobileTwoStep = widget.cashierMode &&
        (widget.mobileStaffMode || ResponsiveHelper.isMobile(context));
    if (cashierMobileTwoStep) {
      final returnEpoch = context
          .select<SalesModel, int>((s) => s.cashierReturnToProductsEpoch);
      if (returnEpoch != _appliedCashierReturnEpoch && returnEpoch > 0) {
        _appliedCashierReturnEpoch = returnEpoch;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _goCashierProductsStep();
        });
      }
      return _buildCashierMobileTwoStepFlow(context);
    }

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

    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.tr('pos'),
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
                            _staffCartPaymentBanner(context),
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
                        onPressed: () => _clearSaleAndRestock(context, sales),
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
                              _staffCartChipLabel(context),
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
                              MntAmountFormatter.formatTugrikSpaced(
                                  sales.total),
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
                    onPressed:
                        sales.isSaleEmpty ? null : _goCashierCheckoutStep,
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
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Баркод унших',
                    icon: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: context.responsiveIconSize(22),
                    ),
                    onPressed: () => _scanBarcodeToSearch(context),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: context.responsiveIconSize(20),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.spacing),
          SizedBox(
            height: context.isMobile ? 36 : 40,
            child: Consumer<InventoryModel>(
              builder: (context, inventory, child) {
                final categoryChips = inventory.categories
                    .where((c) => c != 'Бүгд' && c != 'All')
                    .toList();
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
                        itemCount: categoryChips.length,
                        itemBuilder: (context, index) {
                          final category = categoryChips[index];
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
        // Use raw [inventory.inventory], not [filteredInventory]: the latter applies
        // [InventoryModel]'s global search/category (e.g. from Inventory screen), which
        // would persist and hide products here while this screen's search field stays empty.
        final products = inventory.inventory.where((item) {
          final showAll =
              _selectedCategory == 'Бүгд' || _selectedCategory == 'All';
          final p = item.product;
          final matchesCategory = showAll ||
              p.category == _selectedCategory ||
              p.angilal == _selectedCategory ||
              (p.angilal?.contains(_selectedCategory) == true);
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

        // Keep rows that are still in the *current* sale with in-stock items until the
        // sale is cleared; only then sort true out-of-stock to the bottom.
        bool gridShelfSortActive(InventoryItem i) {
          if (!i.product.isAvailable) return false;
          final inThisSale = _saleQtyForProduct(sales, i.product.id);
          return i.currentStock > 0 || inThisSale > 0;
        }

        DateTime stamp(InventoryItem i) =>
            i.product.updatedAt ??
            i.product.createdAt ??
            i.lastRestocked ??
            DateTime.fromMillisecondsSinceEpoch(0);
        products.sort((a, b) {
          final aa = gridShelfSortActive(a);
          final ab = gridShelfSortActive(b);
          if (aa != ab) return aa ? -1 : 1;
          if (!aa) return stamp(b).compareTo(stamp(a));
          return a.product.name.compareTo(b.product.name);
        });

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
              onTap: (item.currentStock > 0 || inSale > 0)
                  ? () {
                      if (item.currentStock > 0) {
                        sales.addToSale(item.product);
                        inventory.deductStock(item.product.id, 1);
                      }
                      // Shelf is 0 but line still in cart: no reorder/jump; long-press to remove.
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Бүтээгдэхүүн дууссан'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    },
              onRemoveOneFromSale: inSale > 0
                  ? () {
                      inventory.restock(item.product.id, 1);
                      sales.decrementSaleQuantity(item.product.id);
                    }
                  : null,
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
      showBulkAction:
          item.product.buuniiUneEsekh == true &&
          item.product.buuniiUneJagsaalt.isNotEmpty,
      showPromoAction: item.product.uramshuulal.isNotEmpty,
      onBulkTap: () => _showBulkPricingSheet(context, item),
      onPromoTap: () => _showPromotionSheet(context, item),
      onIncrement: () {
        final inventory = context.read<InventoryModel>();
        final inv = inventory.getInventoryItem(item.product.id);
        if (inv == null || inv.currentStock <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                item.product.isBoxSaleUnit
                    ? 'Хайрцагийн үлдэгдэл хүрэлцэхгүй байна'
                    : 'Үлдэгдэл хүрэлцэхгүй байна',
              ),
            ),
          );
          return;
        }
        inventory.deductStock(item.product.id, 1);
        sales.incrementSaleQuantity(item.product.id);
      },
      onDecrement: () {
        final inventory = context.read<InventoryModel>();
        inventory.restock(item.product.id, 1);
        sales.decrementSaleQuantity(item.product.id);
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
                    _staffSalePanelTitle(context),
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: context.responsiveFontSize(18),
                    ),
                  ),
                ),
                if (!sales.isSaleEmpty)
                  TextButton.icon(
                    onPressed: () => _clearSaleAndRestock(context, sales),
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
              onPressed:
                  sales.isSaleEmpty ? null : () => _openPaymentScreen(context),
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
              _sheetSummaryLine(context, 'Дүн', sales.subtotal, false),
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
                    MntAmountFormatter.formatTugrikSpaced(sales.total),
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
              if (widget.mobileStaffMode) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: sales.isSaleEmpty
                      ? null
                      : () => _sendTerminalCardSignal(context, sales),
                  icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                  label: Text(
                    AppLocalizations.of(context)
                        .tr('terminal_signal_send_kiosk'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
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
          MntAmountFormatter.formatTugrikSpaced(amount),
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
          'MNT ${MntAmountFormatter.format(amount)}',
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

  /// Remove one unit from sale + restock (shown as − on card when in sale).
  final VoidCallback? onRemoveOneFromSale;

  const _ProductCard({
    super.key,
    required this.item,
    required this.onTap,
    this.inSaleQuantity = 0,
    this.onRemoveOneFromSale,
  });

  static const Color _stockPlentyGreen = Color(0xFF16A34A);
  static const Color _stockLowRed = Color(0xFFDC2626);

  /// Fixed footer so every grid tile has the same total height (image + info).
  static double _footerHeight(BuildContext context) {
    final fs = context.responsiveFontSize(11);
    final fs9 = context.responsiveFontSize(9);
    final fs10 = context.responsiveFontSize(10);
    final padV = 8.0 + (context.spacing * 0.5 + 4);
    final titleH = fs * 1.2 * 2;
    final codeH = fs9 * 1.25;
    final gapSmall = context.spacing * 0.2;
    final stockH = fs10 * 1.35;
    // spaceBetween gap + small buffer for price alignment
    return (padV + titleH + gapSmall + codeH + 6 + stockH + 2)
        .clamp(90.0, 132.0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final inCart = inSaleQuantity > 0;
    final multiInCart = inSaleQuantity >= 2;
    final stock = item.currentStock;
    final stockHealthy = stock > 20;
    final stockColor = stockHealthy ? _stockPlentyGreen : _stockLowRed;

    final borderColor =
        inCart ? colorScheme.primary : colorScheme.outlineVariant;
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
        onTap: (item.isOutOfStock && !inCart) ? null : onTap,
        onLongPress: (inCart && onRemoveOneFromSale != null)
            ? onRemoveOneFromSale
            : null,
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
                  if (item.isOutOfStock && !inCart)
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
                  if (inCart && onRemoveOneFromSale != null)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onRemoveOneFromSale,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.remove_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: _footerHeight(context),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  10,
                  8,
                  10,
                  context.spacing * 0.5 + 4,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height:
                                    context.responsiveFontSize(11) * 1.2 * 2,
                                width: double.infinity,
                                child: Text(
                                  item.product.name,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: context.responsiveFontSize(11),
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: context.spacing * 0.2),
                              SizedBox(
                                height: context.responsiveFontSize(9) * 1.25,
                                width: double.infinity,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    item.product.code ??
                                        item.product.barCode ??
                                        '',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: context.responsiveFontSize(9),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Tooltip(
                            message: item.product.boxPiecesPerBoxHint ??
                                'Үлдэгдэл: $stock ${item.product.posStockQuantitySuffix}',
                            child: Row(
                              children: [
                                Text(
                                  'Үлдэгдэл: ',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    fontSize: context.responsiveFontSize(9),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '$stock ${item.product.posStockQuantitySuffix}',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: stockColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: context.responsiveFontSize(10),
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: context.spacing * 0.5),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            child: Text(
                              MntAmountFormatter.formatTugrikSpaced(
                                  item.product.price),
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: context.responsiveFontSize(11),
                                height: 1.1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
    required this.showBulkAction,
    required this.showPromoAction,
    required this.onBulkTap,
    required this.onPromoTap,
    this.sheetMode = false,
  });

  final SaleItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final bool showBulkAction;
  final bool showPromoAction;
  final VoidCallback onBulkTap;
  final VoidCallback onPromoTap;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        'MNT ${MntAmountFormatter.format(item.unitPrice)}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.uramshuulaliinId != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 14,
                              color: colorScheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context).tr('pos_sale_promo'),
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (showBulkAction || showPromoAction) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [
                  if (showBulkAction)
                    ActionChip(
                      avatar: const Icon(Icons.layers_outlined, size: 18),
                      label: Text(
                        AppLocalizations.of(context).tr('pos_sale_bulk'),
                        style: textTheme.labelMedium,
                      ),
                      onPressed: onBulkTap,
                    ),
                  if (showPromoAction)
                    ActionChip(
                      avatar: const Icon(Icons.card_giftcard_outlined, size: 18),
                      label: Text(
                        AppLocalizations.of(context).tr('pos_sale_promo'),
                        style: textTheme.labelMedium,
                      ),
                      onPressed: onPromoTap,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Хасах',
                  onPressed: onDecrement,
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 22,
                ),
                SizedBox(
                  width: item.product.isBoxSaleUnit ? 52 : 36,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.product.isBoxSaleUnit)
                        Text(
                          item.product.posStockQuantitySuffix,
                          textAlign: TextAlign.center,
                          style: textTheme.labelSmall?.copyWith(
                            height: 1,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Нэмэх',
                  onPressed: onIncrement,
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 22,
                ),
                IconButton(
                  tooltip: 'Устгах',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 22,
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
                    if (showBulkAction || showPromoAction) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          if (showBulkAction)
                            InkWell(
                              onTap: onBulkTap,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.layers_outlined,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      AppLocalizations.of(context).tr('pos_sale_bulk'),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (showPromoAction)
                            InkWell(
                              onTap: onPromoTap,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.card_giftcard_outlined,
                                      size: 14,
                                      color: colorScheme.tertiary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      AppLocalizations.of(context).tr('pos_sale_promo'),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.tertiary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${MntAmountFormatter.format(item.unitPrice)} × ${item.quantity} ₮',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${MntAmountFormatter.format(lineTotal)} ₮',
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
                          width: item.product.isBoxSaleUnit ? 40 : 28,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${item.quantity}',
                                textAlign: TextAlign.center,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              if (item.product.isBoxSaleUnit)
                                Text(
                                  item.product.posStockQuantitySuffix,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelSmall?.copyWith(
                                    height: 1,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
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
                    tooltip: 'Мөрийг устгах',
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.close_rounded,
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
