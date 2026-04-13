import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/mock_payment_data.dart';
import '../models/auth_model.dart';
import '../models/cart_model.dart';
import '../models/sales_model.dart';
import '../payment/pos_payment_core.dart';
import '../services/pos_transaction_service.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPaymentMethod = MockPaymentData.defaultCheckoutMethodId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _primeOrderNumber());
  }

  Future<void> _primeOrderNumber() async {
    final auth = context.read<AuthModel>();
    final sales = context.read<SalesModel>();
    if (!auth.canSubmitPosSales ||
        sales.isSaleEmpty ||
        sales.guilgeeniiDugaar != null) {
      return;
    }
    try {
      final d = await PosTransactionService().fetchZakhialgiinDugaar();
      if (d != null && d.isNotEmpty && mounted) {
        sales.setGuilgeeniiDugaar(d);
      }
    } catch (_) {}
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    final sales = context.read<SalesModel>();
    final auth = context.read<AuthModel>();

    try {
      if (auth.canSubmitPosSales) {
        final session = auth.posSession!;
        final svc = PosTransactionService();
        var orderNo = sales.guilgeeniiDugaar;
        if (orderNo == null || orderNo.isEmpty) {
          final d = await svc.fetchZakhialgiinDugaar();
          if (d == null || d.isEmpty) {
            throw PosTransactionException('Захиалгын дугаар авах боломжгүй');
          }
          orderNo = d;
          sales.setGuilgeeniiDugaar(d);
        }

        final std = PosPaymentCore.calculateStandardSaleTotals(sales.subtotal);
        await svc.submitGuilgeeniiTuukh(
          session: session,
          sales: sales,
          paymentTurul: PosTransactionService.paymentMethodToTurul(
            _selectedPaymentMethod,
          ),
          niitUne: std.total,
          tulsunDun: std.total,
          hariult: 0,
          hungulsunDun: 0,
          noatiinDun: std.vat,
          noatguiDun: std.subtotal,
          nhatiinDun: 0,
          guilgeeniiDugaar: orderNo,
        );

        if (!mounted) return;
        final completedSale = sales.completeSale(
          _selectedPaymentMethod,
          orderId: orderNo,
        );
        _goReceipt(completedSale);
      } else {
        if (!mounted) return;
        final completedSale = sales.completeSale(_selectedPaymentMethod);
        _goReceipt(completedSale);
      }
    } on PosTransactionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _goReceipt(CompletedSale completedSale) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptScreen(
          items: completedSale.items
              .map((i) => CartItem(product: i.product, quantity: i.quantity))
              .toList(),
          total: completedSale.total,
          paymentMethod: _selectedPaymentMethod,
          orderNumber: completedSale.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<SalesModel>(
        builder: (context, sales, child) {
          if (sales.isSaleEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No items in current sale',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer<AuthModel>(
                        builder: (context, auth, _) {
                          if (!auth.canSubmitPosSales) {
                            return const SizedBox.shrink();
                          }
                          final dugaar = sales.guilgeeniiDugaar;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: colorScheme.primaryContainer
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_done_outlined,
                                      color: colorScheme.primary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        dugaar != null && dugaar.isNotEmpty
                                            ? 'Серверт холбогдсон · Захиалга: $dugaar'
                                            : 'Серверт холбогдсон — дугаар авах гэж байна…',
                                        style: textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Sale Summary
                      Text(
                        'Sale Summary',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...sales.currentSaleItems
                          .map((item) => _buildOrderItem(item)),
                      const Divider(height: 32),
                      _buildPriceSummary(sales),
                      const SizedBox(height: 32),

                      // Payment Methods
                      Text(
                        'Payment Method',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...MockPaymentData.checkoutMethods
                          .map((method) => _buildPaymentMethodTile(method)),
                    ],
                  ),
                ),
              ),

              // Bottom Payment Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: textTheme.titleMedium,
                          ),
                          Text(
                            '\$${sales.total.toStringAsFixed(2)}',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isProcessing ? null : _processPayment,
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Complete Sale'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderItem(SaleItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.product.imageUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 50,
                  height: 50,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.image_not_supported,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${item.total.toStringAsFixed(2)}',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(SalesModel sales) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        _buildPriceRow('Subtotal', sales.subtotal),
        const SizedBox(height: 8),
        _buildPriceRow(
          'Tax (${(MockPaymentData.vatRate * 100).round()}%)',
          sales.tax,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '\$${sales.total.toStringAsFixed(2)}',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, double amount) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(MockPaymentMethodOption method) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedPaymentMethod == method.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => setState(() => _selectedPaymentMethod = method.id),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            method.icon,
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text('${method.label} · ${method.labelMn}'),
        trailing: Radio<String>(
          value: method.id,
          groupValue: _selectedPaymentMethod,
          onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
        ),
      ),
    );
  }
}
