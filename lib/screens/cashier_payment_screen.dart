import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/payment_display_config.dart';
import '../models/auth_model.dart';
import '../models/cart_model.dart';
import '../models/sales_model.dart';
import '../payment/pos_payment_core.dart';
import '../services/pos_transaction_service.dart';
import '../theme/app_theme.dart';
import 'receipt_screen.dart';

/// Cashier: choose **Бэлэн** or **Карт** only; төлөх дүн = сагсны нийт (no tender / numpad).
class CashierPaymentScreen extends StatefulWidget {
  const CashierPaymentScreen({super.key});

  @override
  State<CashierPaymentScreen> createState() => _CashierPaymentScreenState();
}

enum _PayKind { cash, card }

class _CashierPaymentScreenState extends State<CashierPaymentScreen> {
  _PayKind _kind = _PayKind.cash;
  double _discountMnt = 0;
  double _nhhatMnt = 0;
  bool _busy = false;

  late final String _orderPreview;

  static const _surface = Color(0xFF151A21);

  @override
  void initState() {
    super.initState();
    _orderPreview = PaymentDisplayConfig.generateOrderPreview();
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
        setState(() {});
      }
    } catch (_) {}
  }

  String _fmt(double v) {
    final s = NumberFormat('#,###', 'en_US').format(v.round());
    return '$s₮';
  }

  String _methodId(_PayKind k) {
    switch (k) {
      case _PayKind.cash:
        return PosPaymentCore.methodCash;
      case _PayKind.card:
        return PosPaymentCore.methodCard;
    }
  }

  Future<void> _showDiscountDialog() async {
    final controller = TextEditingController(
      text: _discountMnt > 0 ? _discountMnt.round().toString() : '',
    );
    final sales = context.read<SalesModel>();
    final maxD = sales.subtotal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Хөнгөлөлт'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Дүн (₮)',
            hintText: '0',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Болих')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Хадгалах')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final v = double.tryParse(controller.text.trim()) ?? 0;
      setState(() => _discountMnt = v.clamp(0, maxD));
    }
    controller.dispose();
  }

  Future<void> _showNhhatDialog() async {
    final controller = TextEditingController(
      text: _nhhatMnt > 0 ? _nhhatMnt.round().toString() : '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('НХАТ'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Дүн (₮)',
            hintText: '0',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Болих')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Хадгалах')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final v = double.tryParse(controller.text.trim()) ?? 0;
      setState(() => _nhhatMnt = v.clamp(0, 1e12));
    }
    controller.dispose();
  }

  Future<void> _submit(SalesModel sales, double due) async {
    if (sales.isSaleEmpty || _busy) return;

    final auth = context.read<AuthModel>();
    final useApi = auth.canSubmitPosSales;

    setState(() => _busy = true);
    try {
      if (useApi) {
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

        final totals = PosPaymentCore.calculateCashierTotals(
          subtotal: sales.subtotal,
          discountMnt: _discountMnt,
          nhhatMnt: _nhhatMnt,
        );

        await svc.submitGuilgeeniiTuukh(
          session: session,
          sales: sales,
          paymentTurul: PosTransactionService.paymentMethodToTurul(
            _methodId(_kind),
          ),
          niitUne: totals.total,
          tulsunDun: totals.total,
          hariult: 0,
          hungulsunDun: totals.cappedDiscount,
          noatiinDun: totals.vat,
          noatguiDun: totals.net,
          nhatiinDun: totals.nhhat,
          guilgeeniiDugaar: orderNo,
        );

        if (!mounted) return;
        final completed = sales.completeCashierSale(
          paymentMethod: _methodId(_kind),
          discountMnt: _discountMnt,
          nhhatMnt: _nhhatMnt,
          orderId: orderNo,
        );
        _goReceipt(completed);
      } else {
        if (!mounted) return;
        final completed = sales.completeCashierSale(
          paymentMethod: _methodId(_kind),
          discountMnt: _discountMnt,
          nhhatMnt: _nhhatMnt,
          orderId: _orderPreview,
        );
        _goReceipt(completed);
      }
    } on PosTransactionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goReceipt(CompletedSale completed) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptScreen(
          items: completed.items
              .map((i) => CartItem(product: i.product, quantity: i.quantity))
              .toList(),
          total: completed.total,
          paymentMethod: completed.paymentMethod,
          orderNumber: completed.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usePosBackend = context.watch<AuthModel>().canSubmitPosSales;

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _surface,
      ),
      child: Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Төлбөр тооцоо',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: Consumer<SalesModel>(
          builder: (context, sales, _) {
            if (sales.isSaleEmpty) {
              return Center(
                child: Text(
                  'Сагс хоосон',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
              );
            }

            final totals = PosPaymentCore.calculateCashierTotals(
              subtotal: sales.subtotal,
              discountMnt: _discountMnt,
              nhhatMnt: _nhhatMnt,
            );
            final due = totals.total;

            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final pad = EdgeInsets.symmetric(
                  horizontal: wide ? 28 : 16,
                  vertical: 12,
                );

                final orderLabel = usePosBackend
                    ? (sales.guilgeeniiDugaar ?? _orderPreview)
                    : _orderPreview;

                final summary = _SummaryPanel(
                  orderId: orderLabel,
                  subtotal: sales.subtotal,
                  discount: totals.cappedDiscount,
                  vat: totals.vat,
                  nhhat: totals.nhhat,
                  total: totals.total,
                  paymentKindLabel:
                      _kind == _PayKind.cash ? 'Бэлэн мөнгө' : 'Карт',
                  onDiscount: _showDiscountDialog,
                  onNhhat: _showNhhatDialog,
                );

                final payment = _PaymentPanel(
                  kind: _kind,
                  dueFormatted: _fmt(due),
                  onKind: (k) => setState(() => _kind = k),
                  onCancel: () => Navigator.pop(context),
                  onPay: _busy ? null : () => _submit(sales, due),
                  busy: _busy,
                );

                if (wide) {
                  return Padding(
                    padding: pad,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 5, child: summary),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: payment),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: pad,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summary,
                      const SizedBox(height: 20),
                      payment,
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.orderId,
    required this.subtotal,
    required this.discount,
    required this.vat,
    required this.nhhat,
    required this.total,
    required this.paymentKindLabel,
    required this.onDiscount,
    required this.onNhhat,
  });

  final String orderId;
  final double subtotal;
  final double discount;
  final double vat;
  final double nhhat;
  final double total;
  final String paymentKindLabel;
  final VoidCallback onDiscount;
  final VoidCallback onNhhat;

  String _fmt(double v) {
    final s = NumberFormat('#,###', 'en_US').format(v.round());
    return '$s₮';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E252E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3441)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Захиалгын: $orderId',
                  style: const TextStyle(
                    color: AppColors.successDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('Дэд дүн', _fmt(subtotal)),
          _row('Хөнгөлөлт', _fmt(discount), onTap: onDiscount, hint: 'Засах'),
          _row('НӨАТ', _fmt(vat)),
          _row('НХАТ', _fmt(nhhat), onTap: onNhhat, hint: 'Засах'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFF2A3441), height: 1),
          ),
          _row('Нийт дүн', _fmt(total), emphasize: true),
          const SizedBox(height: 6),
          _row('Төлбөрийн төрөл', paymentKindLabel, sub: true),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool emphasize = false,
    bool sub = false,
    bool positive = false,
    VoidCallback? onTap,
    String? hint,
  }) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: sub ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
                  fontSize: sub ? 12 : 13,
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (onTap != null && hint != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 14, color: Colors.white.withOpacity(0.35)),
              ],
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: positive
                  ? AppColors.successDark
                  : (emphasize ? Colors.white : Colors.white.withOpacity(0.92)),
              fontSize: emphasize ? 18 : (sub ? 13 : 14),
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
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

class _PaymentPanel extends StatelessWidget {
  const _PaymentPanel({
    required this.kind,
    required this.dueFormatted,
    required this.onKind,
    required this.onCancel,
    required this.onPay,
    required this.busy,
  });

  final _PayKind kind;
  final String dueFormatted;
  final ValueChanged<_PayKind> onKind;
  final VoidCallback onCancel;
  final VoidCallback? onPay;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    const methods = [
      (_PayKind.cash, 'Бэлэн', Icons.payments_rounded),
      (_PayKind.card, 'Карт', Icons.credit_card_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E252E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3441)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Төлбөрийн төрөл сонгох',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < methods.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _methodTile(methods[i].$1, methods[i].$2, methods[i].$3)),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Төлөх дүн (сагснаас)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2028),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A3441)),
            ),
            child: Text(
              dueFormatted,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 20),
            label: const Text('Цуцлах'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF87171),
              side: const BorderSide(color: Color(0xFF4B2C2C)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onPay,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black54,
                    ),
                  )
                : const Text(
                    'Төлбөр баталгаажуулах',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile(_PayKind k, String label, IconData icon) {
    final sel = kind == k;
    return Material(
      color: sel ? AppColors.success.withOpacity(0.22) : const Color(0xFF252D38),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onKind(k),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: sel ? AppColors.successDark : Colors.white70),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
