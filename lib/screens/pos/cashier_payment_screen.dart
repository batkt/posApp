import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/payment_display_config.dart';
import '../../models/auth_model.dart';
import '../../models/cart_model.dart';
import '../../models/sales_model.dart';
import '../../payment/pos_payment_core.dart';
import '../../services/pos_transaction_service.dart';
import '../../services/qpay_service.dart';
import '../../services/unipos_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/qpay_invoice_dialog.dart';
import '../shared/receipt_screen.dart';

/// Kiosk uses UniPOS card; mobile staff uses merchant QPay API (same as web).
enum CashierTerminalPaymentMode {
  /// Kiosk POS: UniPOS `CARD` only (no terminal QPay).
  cardOnly,
  /// Mobile: `/qpayGargaya` + QR + `/qpayShalgakh` — no UniPOS.
  qpayOnly,
}

/// Cashier: **Бэлэн** / **Карт** or **QPay** / **Данс** (`khariltsakh`), then confirm sheet
/// (бэлэн: олгосон дүн, хариулт; карт/QPay/данс: нийт баталгаажуулах).
class CashierPaymentScreen extends StatefulWidget {
  const CashierPaymentScreen({
    super.key,
    this.terminalMode = CashierTerminalPaymentMode.cardOnly,
  });

  /// [CashierTerminalPaymentMode.cardOnly] for kiosk; [qpayOnly] for `/khyanalt/mobile`.
  final CashierTerminalPaymentMode terminalMode;

  @override
  State<CashierPaymentScreen> createState() => _CashierPaymentScreenState();
}

enum _PayKind { cash, card, dans }

String _fmtMnt(double v) {
  final s = NumberFormat('#,###', 'en_US').format(v.round());
  return '$s₮';
}

class _CashierPaymentScreenState extends State<CashierPaymentScreen> {
  _PayKind _kind = _PayKind.cash;
  double _discountMnt = 0;
  double _nhhatMnt = 0;
  bool _busy = false;
  /// Blocks double-submit before the next frame applies [_busy].
  bool _submitInFlight = false;
  Map<String, dynamic>? _lastEbarimt;

  late final String _orderPreview;

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

  String _methodId(_PayKind k) {
    switch (k) {
      case _PayKind.cash:
        return PosPaymentCore.methodCash;
      case _PayKind.card:
        return widget.terminalMode == CashierTerminalPaymentMode.qpayOnly
            ? PosPaymentCore.methodQpay
            : PosPaymentCore.methodCard;
      case _PayKind.dans:
        return PosPaymentCore.methodAccount;
    }
  }

  String _paymentKindLabelMn(_PayKind k) {
    switch (k) {
      case _PayKind.cash:
        return 'Бэлэн мөнгө';
      case _PayKind.card:
        return widget.terminalMode == CashierTerminalPaymentMode.qpayOnly
            ? 'QPay'
            : 'Карт';
      case _PayKind.dans:
        return 'Данс';
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Болих')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Хадгалах')),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Болих')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Хадгалах')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final v = double.tryParse(controller.text.trim()) ?? 0;
      setState(() => _nhhatMnt = v.clamp(0, 1e12));
    }
    controller.dispose();
  }

  /// After kiosk UniPOS or mobile QPay confirms — `guilgeeniiTuukhKhadgalya` + e-barimt + receipt.
  Future<void> _finalizeApiSale(
    SalesModel sales,
    double tender,
    CashierTotals totals,
  ) async {
    final due = totals.total;
    final isCash = _kind == _PayKind.cash;
    final tulsunDun = isCash ? tender : due;
    final hariult = isCash ? (tender - due).clamp(0.0, double.infinity) : 0.0;

    final auth = context.read<AuthModel>();
    final session = auth.posSession!;
    final svc = PosTransactionService();
    var orderNo = sales.guilgeeniiDugaar;
    String? guilgeeMongoId;
    if (orderNo == null || orderNo.isEmpty) {
      final d = await svc.fetchZakhialgiinDugaar();
      if (d == null || d.isEmpty) {
        throw PosTransactionException('Захиалгын дугаар авах боломжгүй');
      }
      orderNo = d;
      sales.setGuilgeeniiDugaar(d);
    }

    final saveResp = await svc.submitGuilgeeniiTuukh(
      session: session,
      sales: sales,
      paymentTurul: PosTransactionService.paymentMethodToTurul(_methodId(_kind)),
      niitUne: due,
      tulsunDun: tulsunDun,
      hariult: hariult,
      hungulsunDun: totals.cappedDiscount,
      noatiinDun: totals.vat,
      noatguiDun: totals.net,
      nhatiinDun: totals.nhhat,
      guilgeeniiDugaar: orderNo,
    );

    guilgeeMongoId =
        PosTransactionService.parseGuilgeeniiMongoIdFromSaveResponse(saveResp);
    if (guilgeeMongoId != null && guilgeeMongoId.isNotEmpty) {
      _lastEbarimt = await svc.requestCitizenEbarimtAfterSale(
        guilgeeniiMongoId: guilgeeMongoId,
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: session.salbariinId,
      );
    }

    if (!mounted) return;
    final completed = sales.completeCashierSale(
      paymentMethod: _methodId(_kind),
      discountMnt: _discountMnt,
      nhhatMnt: _nhhatMnt,
      orderId: orderNo,
    );
    _goReceipt(
      completed,
      ebarimt: _lastEbarimt,
    );
  }

  /// Web parity: `POST /qpayGargaya` → QR → `POST /qpayShalgakh` (no UniPOS).
  Future<void> _runMobileQpayFlow(
    SalesModel sales,
    CashierTotals totals,
    double tender,
  ) async {
    if (sales.isSaleEmpty || _busy || _submitInFlight) return;

    final auth = context.read<AuthModel>();
    if (!auth.canSubmitPosSales) {
      await _submit(sales, tender, totals: totals);
      return;
    }

    final due = totals.total;
    final session = auth.posSession!;
    final svc = PosTransactionService();

    _submitInFlight = true;
    setState(() => _busy = true);
    _lastEbarimt = null;

    try {
      var orderNo = sales.guilgeeniiDugaar;
      if (orderNo == null || orderNo.isEmpty) {
        final d = await svc.fetchZakhialgiinDugaar();
        if (d == null || d.isEmpty) {
          throw PosTransactionException('Захиалгын дугаар авах боломжгүй');
        }
        orderNo = d;
        if (mounted) sales.setGuilgeeniiDugaar(d);
      }

      final zakhKey = '$orderNo${due.round()}';
      final khariu = await QpayService().gargaya(
        dun: due,
        baiguullagiinId: session.baiguullagiinId,
        salbariinId: session.salbariinId,
        zakhialgiinDugaar: zakhKey,
      );

      if (!mounted) return;

      final paid = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => QpayInvoiceDialog(
          khariu: khariu,
          amountMnt: due,
          baiguullagiinId: session.baiguullagiinId,
          salbariinId: session.salbariinId,
          zakhialgiinDugaar: zakhKey,
        ),
      );

      if (paid != true || !mounted) return;

      await _finalizeApiSale(sales, tender, totals);
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
      _submitInFlight = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  /// [tender] = бэлэн олгосон дүн (вэб `tulburTuluhModal`: `tulsunDun`); картын үед = нийт дүн.
  Future<void> _submit(
    SalesModel sales,
    double tender, {
    required CashierTotals totals,
  }) async {
    if (sales.isSaleEmpty || _busy || _submitInFlight) return;

    final due = totals.total;
    final isCash = _kind == _PayKind.cash; // карт + данс: бүтэн дүн, хариултгүй
    if (isCash && tender + 0.5 < due) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Олгосон дүн (${_fmtMnt(tender)}) нийт дүнгээс (${_fmtMnt(due)}) багасан байна'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final tulsunDun = isCash ? tender : due;

    final auth = context.read<AuthModel>();
    final useApi = auth.canSubmitPosSales;

    _submitInFlight = true;
    setState(() => _busy = true);
    _lastEbarimt = null;
    try {
      if (useApi) {
        if (_kind == _PayKind.card &&
            widget.terminalMode == CashierTerminalPaymentMode.cardOnly) {
          final terminal = await UniPosService.purchase(amount: tulsunDun);
          final paymentType = terminal?['paymentType']?.toString().toUpperCase();
          if (paymentType != null && paymentType.isNotEmpty) {
            final isCard = paymentType == 'CARD';
            if (!isCard) {
              throw PosTransactionException(
                'Касс: зөвхөн карт. QPay хориотой. Төлбөр: $paymentType',
              );
            }
          }
        }
        await _finalizeApiSale(sales, tender, totals);
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
      _submitInFlight = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goReceipt(
    CompletedSale completed, {
    Map<String, dynamic>? ebarimt,
  }) {
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
          ebarimt: ebarimt,
        ),
      ),
    );
  }

  Future<void> _startPayFlow(SalesModel sales, CashierTotals totals) async {
    final due = totals.total;
    final tender = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => Theme(
        data: Theme.of(context),
        child: _TulburConfirmSheet(
          kind: _kind,
          due: due,
          terminalMode: widget.terminalMode,
        ),
      ),
    );
    if (tender != null && mounted) {
      if (widget.terminalMode == CashierTerminalPaymentMode.qpayOnly &&
          _kind == _PayKind.card) {
        await _runMobileQpayFlow(sales, totals, tender);
      } else {
        await _submit(sales, tender, totals: totals);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usePosBackend = context.watch<AuthModel>().canSubmitPosSales;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Төлбөр тооцоо',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Consumer<SalesModel>(
        builder: (context, sales, _) {
            if (sales.isSaleEmpty) {
              final cs = Theme.of(context).colorScheme;
              return Center(
                child: Text(
                  'Сагс хоосон',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
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
                  paymentKindLabel: _paymentKindLabelMn(_kind),
                  onDiscount: _showDiscountDialog,
                  onNhhat: _showNhhatDialog,
                );

                final payment = _PaymentPanel(
                  kind: _kind,
                  terminalMode: widget.terminalMode,
                  dueFormatted: _fmtMnt(due),
                  onKind: (k) => setState(() => _kind = k),
                  onCancel: () => Navigator.pop(context),
                  onPay: _busy ? null : () => _startPayFlow(sales, totals),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                  color: AppColors.success.withValues(alpha: 0.2),
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
          _row(context, 'Дэд дүн', _fmtMnt(subtotal)),
          _row(context, 'Хөнгөлөлт', _fmtMnt(discount),
              onTap: onDiscount, hint: 'Засах'),
          _row(context, 'НӨАТ', _fmtMnt(vat)),
          _row(context, 'НХАТ', _fmtMnt(nhhat), onTap: onNhhat, hint: 'Засах'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: cs.outlineVariant, height: 1),
          ),
          _row(context, 'Нийт дүн', _fmtMnt(total), emphasize: true),
          const SizedBox(height: 6),
          _row(context, 'Төлбөрийн төрөл', paymentKindLabel, sub: true),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
    bool sub = false,
    bool positive = false,
    VoidCallback? onTap,
    String? hint,
  }) {
    final cs = Theme.of(context).colorScheme;
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
                  color: sub ? cs.onSurfaceVariant : cs.onSurface,
                  fontSize: sub ? 12 : 13,
                  fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (onTap != null && hint != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: positive
                  ? AppColors.successDark
                  : (emphasize ? cs.primary : cs.onSurface),
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
    required this.terminalMode,
    required this.dueFormatted,
    required this.onKind,
    required this.onCancel,
    required this.onPay,
    required this.busy,
  });

  final _PayKind kind;
  final CashierTerminalPaymentMode terminalMode;
  final String dueFormatted;
  final ValueChanged<_PayKind> onKind;
  final VoidCallback onCancel;
  final VoidCallback? onPay;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mid = terminalMode == CashierTerminalPaymentMode.qpayOnly
        ? (
            _PayKind.card,
            'QPay',
            Icons.qr_code_2_rounded,
          )
        : (
            _PayKind.card,
            'Карт',
            Icons.credit_card_rounded,
          );
    final methods = [
      (_PayKind.cash, 'Бэлэн', Icons.payments_rounded),
      mid,
      (_PayKind.dans, 'Данс', Icons.account_balance_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Төлбөрийн төрөл сонгох',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < methods.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _methodTile(
                    context,
                    methods[i].$1,
                    methods[i].$2,
                    methods[i].$3,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Төлөх дүн (сагснаас)',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              dueFormatted,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onPay,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: busy
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cs.onPrimary,
                    ),
                  )
                : const Text(
                    'Төлбөр үргэлжлүүлэх',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 20),
            label: const Text('Цуцлах'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodTile(
    BuildContext context,
    _PayKind k,
    String label,
    IconData icon,
  ) {
    final cs = Theme.of(context).colorScheme;
    final sel = kind == k;
    return Material(
      color: sel
          ? cs.primaryContainer.withValues(alpha: 0.65)
          : cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onKind(k),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: sel ? cs.primary : cs.outlineVariant,
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: sel ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: sel ? cs.onPrimaryContainer : cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
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

/// Bottom sheet: card/dans = confirm total; cash = tender + change (вэб `tulburTuluhModal`).
class _TulburConfirmSheet extends StatefulWidget {
  const _TulburConfirmSheet({
    required this.kind,
    required this.due,
    required this.terminalMode,
  });

  final _PayKind kind;
  final double due;
  final CashierTerminalPaymentMode terminalMode;

  @override
  State<_TulburConfirmSheet> createState() => _TulburConfirmSheetState();
}

class _TulburConfirmSheetState extends State<_TulburConfirmSheet> {
  late String _digits;

  static const _sheetRadius = 28.0;

  @override
  void initState() {
    super.initState();
    final d = widget.due.ceil();
    _digits = d <= 0 ? '' : d.toString();
  }

  double get _tender =>
      (int.tryParse(_digits.isEmpty ? '0' : _digits) ?? 0).toDouble();

  double get _hariult => (_tender - widget.due).clamp(0.0, double.infinity);

  bool get _tenderOk => _tender + 0.5 >= widget.due;

  void _tapKey(String key) {
    HapticFeedback.lightImpact();
    _press(key);
  }

  void _press(String key) {
    setState(() {
      switch (key) {
        case '⌫':
          if (_digits.isNotEmpty) {
            _digits = _digits.substring(0, _digits.length - 1);
          }
          break;
        case 'C':
          _digits = '';
          break;
        case '00':
          if (_digits.length < 11) _digits += '00';
          break;
        default:
          if (_digits.length < 12) _digits += key;
      }
    });
  }

  void _setExactDue() {
    HapticFeedback.selectionClick();
    setState(() => _digits = widget.due.ceil().toString());
  }

  void _addQuick(int add) {
    HapticFeedback.selectionClick();
    setState(() {
      final base = int.tryParse(_digits) ?? 0;
      _digits = (base + add).toString();
    });
  }

  Widget _dragHandle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 48,
          height: 5,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }

  BoxDecoration _sheetDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: cs.surface,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
      border: Border(top: BorderSide(color: cs.outlineVariant)),
      boxShadow: [
        BoxShadow(
          color: cs.shadow.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final due = widget.due;
    final cs = Theme.of(context).colorScheme;
    final isSimpleConfirm =
        widget.kind == _PayKind.card || widget.kind == _PayKind.dans;
    final confirmTitle = widget.kind == _PayKind.dans
        ? 'Дансаар төлөх'
        : widget.terminalMode == CashierTerminalPaymentMode.qpayOnly
            ? 'QPay төлөх'
            : 'Картаар төлөх';
    final confirmIcon = widget.kind == _PayKind.dans
        ? Icons.account_balance_rounded
        : widget.terminalMode == CashierTerminalPaymentMode.qpayOnly
            ? Icons.qr_code_2_rounded
            : Icons.credit_card_rounded;

    if (isSimpleConfirm) {
      return Padding(
        padding: EdgeInsets.only(bottom: pad.bottom),
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
          child: Container(
            decoration: _sheetDecoration(context),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dragHandle(context),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primaryContainer.withValues(alpha: 0.55),
                    ),
                    child: Icon(
                      confirmIcon,
                      size: 52,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  confirmTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Нийт төлбөр',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _fmtMnt(due),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context, due);
                        },
                        child: const Text(
                          'Баталгаажуулах',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface,
                          side: BorderSide(color: cs.outlineVariant),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Болих',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
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

    final media = MediaQuery.of(context);
    final viewH = media.size.height;
    final viewW = media.size.width;
    final kb = media.viewInsets.bottom;
    final maxSheetH = (viewH * 0.92) - kb;
    final padH = viewW < 320 ? 10.0 : (viewW < 400 ? 14.0 : 20.0);
    final tenderFont = viewW < 300 ? 22.0 : (viewW < 360 ? 28.0 : (viewW < 420 ? 32.0 : 36.0));
    final titleSize = viewW < 340 ? 16.0 : 18.0;
    final numpadGap = viewW < 340 ? 3.0 : 5.0;
    final keyAspect = viewW < 340 ? 1.85 : (viewW < 400 ? 1.55 : 1.4);
    final keyFontMul = viewW < 340 ? 0.82 : 1.0;

    return Padding(
      padding: EdgeInsets.only(bottom: pad.bottom),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(_sheetRadius)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxSheetH.clamp(200.0, viewH),
            maxWidth: viewW,
          ),
          child: DecoratedBox(
            decoration: _sheetDecoration(context),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(padH, 0, padH, 12 + kb * 0.02),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                _dragHandle(context),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(viewW < 340 ? 8 : 10),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.payments_rounded,
                        color: cs.primary,
                        size: viewW < 340 ? 22 : 26,
                      ),
                    ),
                    SizedBox(width: viewW < 340 ? 8 : 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Бэлэн мөнгө',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: titleSize,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Олгосон дүнг оруулна уу',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: viewW < 340 ? 11 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: viewW < 340 ? 12 : 18),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        flex: 2,
                        child: Text(
                          'Төлөх дүн',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: viewW < 340 ? 12 : 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Flexible(
                        flex: 3,
                        child: Text(
                          _fmtMnt(due),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: viewW < 340 ? 14 : 17,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _tenderOk ? cs.primary : cs.error,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Олгосон',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: _tenderOk ? cs.onSurface : cs.error,
                          fontSize: tenderFont,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _fmtMnt(_tender),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      if (!_tenderOk) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: cs.error,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Олгосон дүн төлөх дүнгээс багагүй байх ёстой',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cs.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _hariult > 0
                      ? Container(
                          key: const ValueKey('change'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.savings_outlined,
                                size: viewW < 340 ? 18 : 20,
                                color: cs.primary,
                              ),
                              SizedBox(width: viewW < 340 ? 6 : 8),
                              Expanded(
                                child: Text(
                                  'Хариулт',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: viewW < 340 ? 13 : 14,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  _fmtMnt(_hariult),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontSize: viewW < 340 ? 16 : 20,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(key: ValueKey('nochange'), height: 0),
                ),
                const SizedBox(height: 16),
                Text(
                  'Хурдан нэмэх',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  children: [
                    _QuickAmountChip(
                      label: 'Нийт дүн',
                      selected: _digits == due.ceil().toString(),
                      onTap: _setExactDue,
                      compact: viewW < 360,
                    ),
                    _QuickAmountChip(
                      label: '+1,000',
                      onTap: () => _addQuick(1000),
                      compact: viewW < 360,
                    ),
                    _QuickAmountChip(
                      label: '+5,000',
                      onTap: () => _addQuick(5000),
                      compact: viewW < 360,
                    ),
                    _QuickAmountChip(
                      label: '+10,000',
                      onTap: () => _addQuick(10000),
                      compact: viewW < 360,
                    ),
                    _QuickAmountChip(
                      label: '+20,000',
                      onTap: () => _addQuick(20000),
                      compact: viewW < 360,
                    ),
                  ],
                ),
                SizedBox(height: viewW < 340 ? 12 : 16),
                _numpad(
                  keyGap: numpadGap,
                  keyAspectRatio: keyAspect,
                  fontScale: keyFontMul,
                ),
                SizedBox(height: viewW < 340 ? 12 : 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: viewW < 340 ? 14 : 18,
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _tenderOk
                            ? () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(context, _tender);
                              }
                            : null,
                        child: Text(
                          'Төлбөр баталгаажуулах',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: viewW < 340 ? 12 : 15,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: viewW < 340 ? 8 : 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface,
                          side: BorderSide(color: cs.outlineVariant),
                          padding: EdgeInsets.symmetric(
                            vertical: viewW < 340 ? 14 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Болих',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: viewW < 340 ? 13 : 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _numpad({
    double keyGap = 5,
    double keyAspectRatio = 1.35,
    double fontScale = 1,
  }) {
    const keys = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    final hPad = EdgeInsets.symmetric(horizontal: keyGap);
    return Column(
      children: [
        for (final row in keys)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (final k in row)
                  Expanded(
                    child: Padding(
                      padding: hPad,
                      child: _NumpadKey(
                        label: k,
                        onTap: () => _tapKey(k),
                        aspectRatio: keyAspectRatio,
                        fontSize: 22 * fontScale,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: hPad,
                  child: _NumpadKey(
                    label: 'C',
                    onTap: () => _tapKey('C'),
                    tone: _NumpadKeyTone.danger,
                    aspectRatio: keyAspectRatio,
                    fontSize: 18 * fontScale,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: hPad,
                  child: _NumpadKey(
                    label: '0',
                    onTap: () => _tapKey('0'),
                    aspectRatio: keyAspectRatio,
                    fontSize: 22 * fontScale,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: hPad,
                  child: _NumpadKey(
                    label: '00',
                    onTap: () => _tapKey('00'),
                    aspectRatio: keyAspectRatio,
                    fontSize: 17 * fontScale,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: hPad,
                  child: _NumpadKey(
                    label: '⌫',
                    onTap: () => _tapKey('⌫'),
                    tone: _NumpadKeyTone.muted,
                    aspectRatio: keyAspectRatio,
                    fontSize: 20 * fontScale,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _NumpadKeyTone { normal, danger, muted }

class _NumpadKey extends StatelessWidget {
  const _NumpadKey({
    required this.label,
    required this.onTap,
    this.tone = _NumpadKeyTone.normal,
    this.fontSize = 22,
    this.aspectRatio = 1.35,
  });

  final String label;
  final VoidCallback onTap;
  final _NumpadKeyTone tone;
  final double fontSize;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    switch (tone) {
      case _NumpadKeyTone.danger:
        bg = cs.errorContainer;
        fg = cs.error;
        break;
      case _NumpadKeyTone.muted:
        bg = cs.surfaceContainerHighest.withValues(alpha: 0.85);
        fg = cs.onSurfaceVariant;
        break;
      case _NumpadKeyTone.normal:
        bg = cs.surfaceContainerHighest.withValues(alpha: 0.55);
        fg = cs.onSurface;
        break;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: cs.primary.withValues(alpha: 0.12),
        highlightColor: cs.primary.withValues(alpha: 0.06),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  const _QuickAmountChip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.65)
          : cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? cs.onPrimaryContainer : cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ),
      ),
    );
  }
}
