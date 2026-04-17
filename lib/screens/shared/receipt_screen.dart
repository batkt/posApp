import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/payment_display_config.dart';
import '../../models/cart_model.dart';
import '../../services/printer_service.dart';
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

  static List<Map<String, dynamic>> _extractEbarimtItems(
      Map<String, dynamic>? e) {
    if (e == null) return const [];
    for (final key in const ['items', 'products', 'baraanuud', 'details']) {
      final raw = e[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    }
    return const [];
  }

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
      final e = ebarimt;
      final totalAmount =
          _num(e?['amount']) > 0 ? _num(e?['amount']) : _num(e?['totalAmount']);
      final dbRefNo =
          _str(e?['billId']).isNotEmpty ? _str(e?['billId']) : _str(e?['id']);
      final result = await PrinterService.printReceiptImage(
        pngBytes,
        amount: totalAmount > 0 ? totalAmount : total,
        dbRefNo: dbRefNo.isNotEmpty ? dbRefNo : orderNumber,
      );
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
    final e = ebarimt;
    final totalAmount =
        _num(e?['amount']) > 0 ? _num(e?['amount']) : _num(e?['totalAmount']);
    final totalVat =
        _num(e?['vat']) > 0 ? _num(e?['vat']) : _num(e?['totalVAT']);
    final totalCityTax = _num(e?['cityTax']) > 0
        ? _num(e?['cityTax'])
        : _num(e?['totalCityTax']);
    final ebarimtType =
        _str(e?['customerTin']).isNotEmpty || _str(e?['register']).length == 7
            ? 'ААН'
            : 'Иргэн';
    final ebarimtDate = _str(e?['date']);
    final ebarimtBillId =
        _str(e?['billId']).isNotEmpty ? _str(e?['billId']) : _str(e?['id']);
    final ebarimtRegister = _str(e?['register']);
    final ebarimtCustomerTin = _str(e?['customerTin']);
    final ebarimtLottery = _str(e?['lottery']);
    final ebarimtItems = _extractEbarimtItems(e);
    final qrData = _str(e?['qrData']);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'И-Баримт бэлэн',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                _fmtMnt(total),
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Захиалга: $orderNumber',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            MongolianDateFormatter.formatDateTime(DateTime.now()),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (e != null) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Text(
                              'И-БАРИМТ · $ebarimtType',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (ebarimtDate.isNotEmpty)
                              _detailRow(context, 'Огноо', ebarimtDate),
                            if (ebarimtBillId.isNotEmpty)
                              _detailRow(context, 'ДДТД', ebarimtBillId),
                            if (ebarimtRegister.isNotEmpty)
                              _detailRow(context, 'Регистр', ebarimtRegister),
                            if (ebarimtCustomerTin.isNotEmpty)
                              _detailRow(
                                  context, 'Харилцагч ТТД', ebarimtCustomerTin),
                            if (ebarimtLottery.isNotEmpty)
                              _detailRow(context, 'Сугалаа', ebarimtLottery),
                            if (totalAmount > 0)
                              _detailRow(context, 'Нийт дүн', _fmtMnt(totalAmount)),
                            if (totalVat > 0)
                              _detailRow(context, 'НӨАТ', _fmtMnt(totalVat)),
                            if (totalCityTax > 0)
                              _detailRow(context, 'НХАТ', _fmtMnt(totalCityTax)),
                            const SizedBox(height: 10),
                            Text(
                              'Бараа',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...(ebarimtItems.isNotEmpty
                                    ? ebarimtItems
                                    : items
                                        .map((i) => {
                                              'name': i.product.name,
                                              'qty': i.quantity,
                                              'amount': i.total,
                                            })
                                        .toList())
                                .take(12)
                                .map((item) => _ebarimtItemRow(context, item)),
                            if ((ebarimtItems.isNotEmpty
                                        ? ebarimtItems.length
                                        : items.length) >
                                    12)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+${(ebarimtItems.isNotEmpty ? ebarimtItems.length : items.length) - 12} мөр...',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                          if (qrData.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 120,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedOverflowBox(
                      size: Size.zero,
                      alignment: Alignment.topLeft,
                      child: Transform.translate(
                        offset: const Offset(-5000, 0),
                        child: RepaintBoundary(
                          key: _printKey,
                          child: Container(
                        color: Colors.white,
                        width: 380,
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'POSEASE БАРИМТ',
                              textAlign: TextAlign.center,
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Захиалга: $orderNumber',
                              textAlign: TextAlign.center,
                              style: textTheme.labelLarge?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              MongolianDateFormatter.formatDateTime(
                                DateTime.now(),
                              ),
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.black,
                                fontSize: 15,
                                fontFeatures: const [
                                  ui.FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '----------------------------------------------',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Бараа',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${items.length}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...items.take(8).map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.quantity}x ${item.product.name}',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _fmtMnt(item.total),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        fontFeatures: const [
                                          ui.FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (items.length > 8)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 4),
                                child: Text(
                                  '+${items.length - 8} бараа...',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            const Text(
                              '----------------------------------------------',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Төлбөр',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 17,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _paymentMethodName,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Нийт дүн',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.black,
                                    fontSize: 17,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _fmtMnt(totalAmount > 0 ? totalAmount : total),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                            if (totalVat > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    'НӨАТ',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.black,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _fmtMnt(totalVat),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.black,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (totalCityTax > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    'НХАТ',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.black,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _fmtMnt(totalCityTax),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.black,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'ТӨЛӨХ ДҮН',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.7,
                                    fontSize: 23,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _fmtMnt(total),
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 23,
                                    fontFeatures: const [
                                      ui.FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (e != null) ...[
                              const SizedBox(height: 6),
                              const Text(
                                '----------------------------------------------',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'И-БАРИМТ · $ebarimtType',
                                textAlign: TextAlign.center,
                                style: textTheme.labelLarge?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              if (ebarimtDate.isNotEmpty)
                                Text(
                                  ebarimtDate,
                                  textAlign: TextAlign.center,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                              if (_str(e['lottery']).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Сугалаа: ${_str(e['lottery'])}',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (qrData.isNotEmpty)
                                    QrImageView(
                                      data: qrData,
                                      version: QrVersions.auto,
                                      size: 280,
                                      backgroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Colors.black,
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: Colors.black,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.qr_code_2_rounded,
                                      size: 96,
                                      color: Colors.black,
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    qrData.isNotEmpty
                                        ? 'QR уншуулаад баримтаа шалгана уу'
                                        : 'QR мэдээлэл олдсонгүй',
                                    textAlign: TextAlign.center,
                                    style: textTheme.labelMedium?.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Баярлалаа',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          ),
                        ),
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

  Widget _detailRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ebarimtItemRow(BuildContext context, Map<String, dynamic> item) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = _str(item['name']).isNotEmpty
        ? _str(item['name'])
        : (_str(item['ner']).isNotEmpty ? _str(item['ner']) : 'Бараа');
    final qty = _num(item['qty']) > 0 ? _num(item['qty']) : _num(item['too']);
    final amount = _num(item['amount']) > 0
        ? _num(item['amount'])
        : (_num(item['totalAmount']) > 0
            ? _num(item['totalAmount'])
            : _num(item['niitUne']));
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              qty > 0 ? '${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)}x $name' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtMnt(amount),
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

}
