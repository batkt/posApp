import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/payment_display_config.dart';
import '../../models/auth_model.dart';
import '../../models/cart_model.dart';
import '../../models/customer_model.dart';
import '../../models/sales_model.dart';
import '../../payment/pos_payment_core.dart';
import '../../services/khariltsagch_service.dart';
import '../../services/pos_transaction_service.dart';
import '../../services/qpay_service.dart';
import '../../services/unipos_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../widgets/qpay_invoice_dialog.dart';
import '../shared/receipt_screen.dart';

/// Default cashier terminal: UniPOS card (kiosk and mobile staff).
enum CashierTerminalPaymentMode {
  /// UniPOS `CARD` only (no terminal QPay).
  cardOnly,

  /// Merchant QPay API (`/qpayGargaya` …) instead of UniPOS — optional / legacy.
  qpayOnly,
}

/// Cashier: **Бэлэн** / **Карт** or **QPay** / **Данс** (`khariltsakh`) / **Зээл** (`zeel`).
/// Бэлэн: дүн + хариултын sheet; карт/данс/QPay: шууд терминал / QPay; зээл: харилцагч сонгоод API.
class CashierPaymentScreen extends StatefulWidget {
  const CashierPaymentScreen({
    super.key,
    this.terminalMode = CashierTerminalPaymentMode.cardOnly,
  });

  /// [CashierTerminalPaymentMode.cardOnly] for UniPOS card (kiosk and mobile staff).
  final CashierTerminalPaymentMode terminalMode;

  @override
  State<CashierPaymentScreen> createState() => _CashierPaymentScreenState();
}

enum _PayKind { cash, card, dans, zeel }

String _fmtMnt(double v) => MntAmountFormatter.formatTugrik(v);

class _CashierPaymentScreenState extends State<CashierPaymentScreen> {
  _PayKind _kind = _PayKind.cash;
  double _discountMnt = 0;
  double _nhhatMnt = 0;
  bool _busy = false;

  /// Blocks double-submit before the next frame applies [_busy].
  bool _submitInFlight = false;

  late final String _orderPreview;
  late final TextEditingController _discountInput;
  late final FocusNode _discountFocus;

  @override
  void initState() {
    super.initState();
    _discountInput = TextEditingController();
    _discountFocus = FocusNode();
    _orderPreview = PaymentDisplayConfig.generateOrderPreview();
    WidgetsBinding.instance.addPostFrameCallback((_) => _primeOrderNumber());
  }

  @override
  void dispose() {
    _discountInput.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  void _onDiscountTextChanged(double maxSubtotal) {
    final raw = MntAmountFormatter.parseUserAmount(_discountInput.text);
    final v = raw.clamp(0.0, maxSubtotal);
    setState(() => _discountMnt = v);
    if (raw > maxSubtotal + 0.01 && _discountInput.text.isNotEmpty) {
      final t = v > 0.009 ? MntAmountFormatter.format(v) : '';
      if (t != _discountInput.text) {
        _discountInput.value = TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(offset: t.length),
        );
      }
    }
  }

  void _formatDiscountFieldForDisplay(double maxSubtotal) {
    final v = _discountMnt.clamp(0.0, maxSubtotal);
    setState(() => _discountMnt = v);
    _discountInput.text = v > 0.009 ? MntAmountFormatter.format(v) : '';
    _discountInput.selection =
        TextSelection.collapsed(offset: _discountInput.text.length);
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
      case _PayKind.zeel:
        return PosPaymentCore.methodCredit;
    }
  }

  String _paymentKindLabelMn(_PayKind k) {
    switch (k) {
      case _PayKind.cash:
        return 'Бэлэн төлөлт';
      case _PayKind.card:
        return widget.terminalMode == CashierTerminalPaymentMode.qpayOnly
            ? 'QPay'
            : 'Карт';
      case _PayKind.dans:
        return 'Данс';
      case _PayKind.zeel:
        return 'Зээл';
    }
  }

  /// After kiosk UniPOS or mobile QPay confirms — `guilgeeniiTuukhKhadgalya` + e-barimt + receipt.
  Future<void> _finalizeApiSale(
    SalesModel sales,
    double tender,
    CashierTotals totals, {
    String? zeelKhariltsagchiinId,
  }) async {
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
      paymentTurul:
          PosTransactionService.paymentMethodToTurul(_methodId(_kind)),
      niitUne: due,
      tulsunDun: tulsunDun,
      hariult: hariult,
      hungulsunDun: totals.cappedDiscount,
      noatiinDun: totals.vat,
      noatguiDun: totals.net,
      nhatiinDun: totals.nhhat,
      guilgeeniiDugaar: orderNo,
      zeelKhariltsagchiinId: zeelKhariltsagchiinId,
    );

    guilgeeMongoId =
        PosTransactionService.parseGuilgeeniiMongoIdFromSaveResponse(saveResp);

    if (!mounted) return;
    final completed = sales.completeCashierSale(
      paymentMethod: _methodId(_kind),
      discountMnt: _discountMnt,
      nhhatMnt: _nhhatMnt,
      orderId: orderNo,
    );
    _goReceipt(
      completed,
      guilgeeniiMongoId: guilgeeMongoId,
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

      await _finalizeApiSale(sales, tender, totals, zeelKhariltsagchiinId: null);
    } on PosTransactionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(posPaymentErrorUserMessage(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(posPaymentErrorUserMessage(e)),
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
    String? zeelKhariltsagchiinId,
  }) async {
    if (sales.isSaleEmpty || _busy || _submitInFlight) return;

    final due = totals.total;
    // Бэлэн: олгосон дүн + хариулт; карт/данс/зээл: нийт дүнээр, хариултгүй.
    final isCash = _kind == _PayKind.cash;
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
    try {
      if (useApi) {
        if (_kind == _PayKind.card &&
            widget.terminalMode == CashierTerminalPaymentMode.cardOnly) {
          final terminal = await UniPosService.purchase(amount: tulsunDun);
          UniPosService.requireSuccessfulTerminalCardPayment(terminal);
        }
        await _finalizeApiSale(
          sales,
          tender,
          totals,
          zeelKhariltsagchiinId: zeelKhariltsagchiinId,
        );
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
            content: Text(posPaymentErrorUserMessage(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(posPaymentErrorUserMessage(e)),
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
    String? guilgeeniiMongoId,
  }) {
    final t = PosPaymentCore.calculateCashierTotals(
      subtotal: completed.subtotal,
      discountMnt: completed.discount,
      nhhatMnt: completed.nhhat,
    );
    final slip = (completed.discount > 0.009 || completed.nhhat > 0.009)
        ? CashierSlipTotals(
            grossSubtotal: completed.subtotal,
            discount: t.cappedDiscount,
            noatgui: t.net,
            noat: t.vat,
            nhat: t.nhhat,
            payable: t.total,
          )
        : null;
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
          guilgeeniiMongoId: guilgeeniiMongoId,
          cashierSlipTotals: slip,
        ),
      ),
    );
  }

  Future<void> _startPayFlow(SalesModel sales, CashierTotals totals) async {
    final due = totals.total;

    if (_kind == _PayKind.cash) {
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
          ),
        ),
      );
      if (tender != null && mounted) {
        await _submit(sales, tender, totals: totals);
      }
      return;
    }

    if (_kind == _PayKind.zeel) {
      if (!mounted) return;
      final session = context.read<AuthModel>().posSession;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('POS сесс олдсонгүй'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final id = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (ctx) => Theme(
          data: Theme.of(context),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: _ZeelCustomerPickerSheet(
                baiguullagiinId: session.baiguullagiinId,
                salbariinId: session.salbariinId,
              ),
            ),
          ),
        ),
      );
      if (id == null || !mounted) return;
      await _submit(
        sales,
        due,
        totals: totals,
        zeelKhariltsagchiinId: id,
      );
      return;
    }

    if (!mounted) return;
    if (widget.terminalMode == CashierTerminalPaymentMode.qpayOnly &&
        _kind == _PayKind.card) {
      await _runMobileQpayFlow(sales, totals, due);
    } else {
      await _submit(sales, due, totals: totals);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthModel>();
    final usePosBackend = auth.canSubmitPosSales;
    final showZeelOption =
        usePosBackend && auth.staffAccess.allowsKhariltsagch;

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

          final effectiveDiscount =
              _discountMnt.clamp(0.0, sales.subtotal).toDouble();
          if (effectiveDiscount != _discountMnt) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _discountMnt = effectiveDiscount;
                if (!_discountFocus.hasFocus) {
                  _discountInput.text = effectiveDiscount > 0.009
                      ? MntAmountFormatter.format(effectiveDiscount)
                      : '';
                }
              });
            });
          }
          final totals = PosPaymentCore.calculateCashierTotals(
            subtotal: sales.subtotal,
            discountMnt: effectiveDiscount,
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
                discountController: _discountInput,
                discountFocus: _discountFocus,
                onDiscountChanged: () =>
                    _onDiscountTextChanged(sales.subtotal),
                onDiscountEditingComplete: () =>
                    _formatDiscountFieldForDisplay(sales.subtotal),
              );

              final payment = _PaymentPanel(
                kind: _kind,
                terminalMode: widget.terminalMode,
                showZeelOption: showZeelOption,
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
    required this.discountController,
    required this.discountFocus,
    required this.onDiscountChanged,
    required this.onDiscountEditingComplete,
  });

  final String orderId;
  final double subtotal;
  final double discount;
  final double vat;
  final double nhhat;
  final double total;
  final String paymentKindLabel;
  final TextEditingController discountController;
  final FocusNode discountFocus;
  final VoidCallback onDiscountChanged;
  final VoidCallback onDiscountEditingComplete;

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
                  color: AppColors.successContainer,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Захиалгын: $orderId',
                  style: const TextStyle(
                    color: AppColors.onSuccessContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row(context, 'Дэд дүн', _fmtMnt(subtotal)),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Хөнгөлөлт (₮)',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ListenableBuilder(
                  listenable: discountController,
                  builder: (context, _) {
                    return TextField(
                      controller: discountController,
                      focusNode: discountFocus,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,\s]')),
                      ],
                      onChanged: (_) => onDiscountChanged(),
                      onEditingComplete: onDiscountEditingComplete,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        isDense: true,
                        filled: true,
                        fillColor: cs.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: discountController.text.trim().isNotEmpty
                            ? IconButton(
                                tooltip: 'Арилгах',
                                onPressed: () {
                                  discountController.clear();
                                  onDiscountChanged();
                                },
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 20,
                                  color: cs.outline,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Дээд ${_fmtMnt(subtotal)} · одоо тооцоололд ${_fmtMnt(discount)}',
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _row(context, 'НӨАТ', _fmtMnt(vat)),
          _row(context, 'НХАТ', _fmtMnt(nhhat)),
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
    bool accent = false,
    VoidCallback? onTap,
    String? hint,
  }) {
    final cs = Theme.of(context).colorScheme;
    final valueColor = positive
        ? AppColors.onSuccessContainer
        : (emphasize
            ? cs.primary
            : (accent ? cs.primary : cs.onSurface));
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
              color: valueColor,
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
    required this.showZeelOption,
    required this.dueFormatted,
    required this.onKind,
    required this.onCancel,
    required this.onPay,
    required this.busy,
  });

  final _PayKind kind;
  final CashierTerminalPaymentMode terminalMode;
  final bool showZeelOption;
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
    final methods = <(_PayKind, String, IconData)>[
      (_PayKind.cash, 'Бэлэн', Icons.payments_rounded),
      mid,
      (_PayKind.dans, 'Данс', Icons.account_balance_rounded),
    ];
    if (showZeelOption) {
      methods.add((_PayKind.zeel, 'Зээл', Icons.schedule_outlined));
    }

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
          if (methods.length <= 3)
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
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _methodTile(
                        context,
                        methods[0].$1,
                        methods[0].$2,
                        methods[0].$3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _methodTile(
                        context,
                        methods[1].$1,
                        methods[1].$2,
                        methods[1].$3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _methodTile(
                        context,
                        methods[2].$1,
                        methods[2].$2,
                        methods[2].$3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _methodTile(
                        context,
                        methods[3].$1,
                        methods[3].$2,
                        methods[3].$3,
                      ),
                    ),
                  ],
                ),
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

/// Web `zeelModal.js`: [khariltsagchiinId] for `tulbur.turul === "zeel"`.
class _ZeelCustomerPickerSheet extends StatefulWidget {
  const _ZeelCustomerPickerSheet({
    required this.baiguullagiinId,
    required this.salbariinId,
  });

  final String baiguullagiinId;
  final String salbariinId;

  @override
  State<_ZeelCustomerPickerSheet> createState() =>
      _ZeelCustomerPickerSheetState();
}

class _ZeelCustomerPickerSheetState extends State<_ZeelCustomerPickerSheet> {
  final _search = TextEditingController();
  final _service = KhariltsagchService();
  Timer? _debounce;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    final r = await _service.fetchList(
      baiguullagiinId: widget.baiguullagiinId,
      salbariinId: widget.salbariinId,
      search: _search.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.success) {
        _rows = r.rows;
      } else {
        _err = r.error;
        _rows = [];
      }
    });
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.65;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Зээл',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Харилцагч сонгоно уу',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'Хайх',
                  hintText: 'Нэр, утас, имэйл, регистр…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (_) => _scheduleLoad(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading && _rows.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _err != null && _rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _err!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.error),
                            ),
                          ),
                        )
                      : _rows.isEmpty
                          ? Center(
                              child: Text(
                                'Харилцагч олдсонгүй',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final m = _rows[i];
                                final c = Customer.fromKhariltsagch(m);
                                final id = m['_id']?.toString() ?? '';
                                return ListTile(
                                  title: Text(
                                    c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    c.phone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(
                                      Icons.chevron_right_rounded),
                                  onTap: id.isEmpty
                                      ? null
                                      : () => Navigator.pop(context, id),
                                );
                              },
                            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Болих'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: бэлэн = tender + change (вэб `tulburTuluhModal`). Карт/данс: шууд төлөлт.
class _TulburConfirmSheet extends StatefulWidget {
  const _TulburConfirmSheet({
    required this.kind,
    required this.due,
  });

  final _PayKind kind;
  final double due;

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
        default:
          if (_digits.length < 12) _digits += key;
      }
    });
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

    final media = MediaQuery.of(context);
    final viewH = media.size.height;
    final viewW = media.size.width;
    final kb = media.viewInsets.bottom;
    final maxSheetH = (viewH * 0.92) - kb;
    final padH = viewW < 320 ? 10.0 : (viewW < 400 ? 14.0 : 20.0);
    final tenderFont =
        viewW < 300 ? 22.0 : (viewW < 360 ? 28.0 : (viewW < 420 ? 32.0 : 36.0));
    final titleSize = viewW < 340 ? 14.0 : 16.0;
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _dragHandle(context),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(viewW < 340 ? 7 : 8),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.payments_rounded,
                          color: cs.primary,
                          size: viewW < 340 ? 18 : 21,
                        ),
                      ),
                      SizedBox(width: viewW < 340 ? 8 : 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Бэлэн төлөлт',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: titleSize,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: viewW < 340 ? 12 : 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                          'Дүн бичих',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
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
                          const SizedBox(height: 8),
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
                              color:
                                  cs.primaryContainer.withValues(alpha: 0.45),
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
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAmountChip(
                          label: '+1,000',
                          onTap: () => _addQuick(1000),
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAmountChip(
                          label: '+5,000',
                          onTap: () => _addQuick(5000),
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAmountChip(
                          label: '+10,000',
                          onTap: () => _addQuick(10000),
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickAmountChip(
                          label: '+20,000',
                          onTap: () => _addQuick(20000),
                          compact: true,
                        ),
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
                            'Төлөх',
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
    final sideAspect = keyAspectRatio;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: hPad,
            child: Column(
              children: [
                for (final k in ['C', '0', '⌫'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _NumpadKey(
                      label: k,
                      onTap: () => _tapKey(k),
                      tone: k == 'C'
                          ? _NumpadKeyTone.danger
                          : k == '⌫'
                              ? _NumpadKeyTone.muted
                              : _NumpadKeyTone.normal,
                      aspectRatio: sideAspect,
                      fontSize: 21 * fontScale,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
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
                              fontSize: 21 * fontScale,
                            ),
                          ),
                        ),
                    ],
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
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
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
              color: cs.outlineVariant,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ),
      ),
    );
  }
}
