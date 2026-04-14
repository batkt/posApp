import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/payment_display_config.dart';
import '../../models/cart_model.dart';
import '../../models/locale_model.dart';
import '../../services/printer_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/mnt_amount_formatter.dart';
import '../../utils/mongolian_date_formatter.dart';

class ReceiptScreen extends StatelessWidget {
  ReceiptScreen({
    super.key,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.orderNumber,
    this.ebarimt,
  });

  final GlobalKey _printKey = GlobalKey();

  final List<CartItem> items;
  final double total;
  final String paymentMethod;
  final String orderNumber;
  final Map<String, dynamic>? ebarimt;

  String get _paymentMethodName => PaymentDisplayConfig.labelMn(paymentMethod);

  IconData get _paymentMethodIcon =>
      PaymentDisplayConfig.iconForMethod(paymentMethod);

  void _startNewOrder(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static String _fmtMnt(double v) => MntAmountFormatter.formatTugrik(v);

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();

  Future<void> _printOnPaxDevice(
    BuildContext context, {
    bool allowPdfFallback = true,
  }) async {
    try {
      final boundary = _printKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Print boundary not ready');
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Unable to render print image');
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final result = await PrinterService.printReceiptImage(pngBytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
          ),
        );
      }
      final lower = result.message.toLowerCase();
      if (!result.success &&
          allowPdfFallback &&
          (lower.contains('neptuneliteuser') ||
              lower.contains('classnotfound') ||
              lower.contains('neptune sdk not found'))) {
        await _printViaSystemDialog();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Терминал хэвлэгч байхгүй тул системийн хэвлэх цонх нээгдлээ'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Терминал хэвлэх алдаа: $e'),
          ),
        );
      }
    }
  }

  Future<void> _printViaSystemDialog() async {
    final e = ebarimt;
    final totalAmount =
        _num(e?['amount']) > 0 ? _num(e?['amount']) : _num(e?['totalAmount']);
    final totalVat =
        _num(e?['vat']) > 0 ? _num(e?['vat']) : _num(e?['totalVAT']);
    final ddtd =
        _str(e?['billId']).isNotEmpty ? _str(e?['billId']) : _str(e?['id']);
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('E-BARIMT'),
            pw.Text('DDTD: $ddtd'),
            pw.Text('Amount: ${MntAmountFormatter.format(totalAmount)}'),
            pw.Text('VAT: ${MntAmountFormatter.format(totalVat)}'),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final pieceCount = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final qtySummary = l10n
        .tr('receipt_qty_summary')
        .replaceAll('{pieces}', '$pieceCount')
        .replaceAll('{lines}', '${items.length}');
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final vatAmount = subtotal * PaymentDisplayConfig.vatRate;
    final e = ebarimt;
    final totalAmount =
        _num(e?['amount']) > 0 ? _num(e?['amount']) : _num(e?['totalAmount']);
    final totalVat =
        _num(e?['vat']) > 0 ? _num(e?['vat']) : _num(e?['totalVAT']);
    final totalCityTax = _num(e?['cityTax']) > 0
        ? _num(e?['cityTax'])
        : _num(e?['totalCityTax']);
    final totalNoatgui = totalAmount - totalVat - totalCityTax;
    final ddtd =
        _str(e?['billId']).isNotEmpty ? _str(e?['billId']) : _str(e?['id']);
    final ebarimtType =
        _str(e?['customerTin']).isNotEmpty || _str(e?['register']).length == 7
            ? 'ААН'
            : 'Иргэн';
    final ebarimtStatus =
        _str(e?['status']).isNotEmpty ? _str(e?['status']) : 'SUCCESS';
    final ebarimtDate = _str(e?['date']);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Success Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 48,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Төлбөр амжилттай!',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Худалдан авалтад баярлалаа',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      qtySummary,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fmtMnt(total),
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Receipt Card
                    RepaintBoundary(
                      key: _printKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            // Receipt Header
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.point_of_sale,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'posEase',
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Албан ёсны баримт',
                                    style: textTheme.titleSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  // Order Info
                                  _buildInfoRow(
                                      context, 'Захиалгын дугаар', orderNumber),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    context,
                                    'Огноо',
                                    MongolianDateFormatter.formatDateTime(
                                        DateTime.now()),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        _paymentMethodIcon,
                                        size: 16,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Төлбөрийн хэлбэр: $_paymentMethodName',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 32),

                                  // Items
                                  ...items.map((item) =>
                                      _buildReceiptItem(context, item)),

                                  const Divider(height: 32),

                                  // Totals
                                  _buildReceiptTotalRow(
                                    context,
                                    'Дэд дүн',
                                    subtotal,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildReceiptTotalRow(
                                    context,
                                    'НӨАТ (${(PaymentDisplayConfig.vatRate * 100).round()}%)',
                                    vatAmount,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'НИЙТ ТӨЛӨГДСӨН',
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color:
                                                colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                        Text(
                                          _fmtMnt(total),
                                          style: textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color:
                                                colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (e != null) ...[
                                    const Divider(height: 32),
                                    _buildInfoRow(context, '№', '1'),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                      context,
                                      'Огноо',
                                      ebarimtDate.isNotEmpty
                                          ? ebarimtDate
                                          : MongolianDateFormatter
                                              .formatDateTime(
                                              DateTime.now(),
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(context, 'Баримтын дугаар',
                                        orderNumber),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                        context, 'Төрөл', ebarimtType),
                                    const SizedBox(height: 8),
                                    _buildReceiptTotalRow(
                                        context, 'Дүн', totalAmount),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                        context, 'Төлөв', ebarimtStatus),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(context, 'ДДТД', ddtd),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                        context, 'ТТД', _str(e['merchantTin'])),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(
                                        context, 'Касс', _str(e['posNo'])),
                                    const SizedBox(height: 8),
                                    _buildReceiptTotalRow(
                                        context, 'НӨАТ-гүй дүн', totalNoatgui),
                                    const SizedBox(height: 8),
                                    _buildReceiptTotalRow(
                                        context, 'НӨАТ', totalVat),
                                    const SizedBox(height: 8),
                                    _buildReceiptTotalRow(
                                        context, 'НХАТ', totalCityTax),
                                    const SizedBox(height: 8),
                                    _buildReceiptTotalRow(
                                        context, 'Е-Баримт дүн', totalAmount),
                                    if (_str(e['lottery']).isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoRow(context, 'Сугалааны дугаар',
                                          _str(e['lottery'])),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _startNewOrder(context),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Шинэ захиалга эхлүүлэх'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (ebarimt != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _printOnPaxDevice(context),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('И-Баримт хэвлэх'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
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
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptItem(BuildContext context, CartItem item) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${item.quantity}x',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
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
                  '${_fmtMnt(item.product.price)} / нэгж',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _fmtMnt(item.total),
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptTotalRow(
      BuildContext context, String label, double amount) {
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
          _fmtMnt(amount),
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
