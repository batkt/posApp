import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../data/payment_display_config.dart';
import '../models/cart_model.dart';
import '../services/pos_transaction_service.dart';
import '../theme/app_theme.dart';
import '../utils/mongolian_date_formatter.dart';

class ReceiptScreen extends StatelessWidget {
  final List<CartItem> items;
  final double total;
  final String paymentMethod;
  final String orderNumber;
  final Map<String, dynamic>? ebarimt;
  final String? guilgeeMongoId;
  final String? baiguullagiinId;
  final String? salbariinId;

  const ReceiptScreen({
    super.key,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.orderNumber,
    this.ebarimt,
    this.guilgeeMongoId,
    this.baiguullagiinId,
    this.salbariinId,
  });

  String get _paymentMethodName => PaymentDisplayConfig.labelMn(paymentMethod);

  IconData get _paymentMethodIcon =>
      PaymentDisplayConfig.iconForMethod(paymentMethod);

  void _startNewOrder(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  static String _fmtMnt(double v) {
    final s = NumberFormat('#,###', 'en_US').format(v.round());
    return '$s₮';
  }

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static String _str(dynamic v) => (v ?? '').toString().trim();

  Future<void> _shareReceipt(BuildContext context) async {
    final date = MongolianDateFormatter.formatDateTime(DateTime.now());
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
    final lottery = _str(e?['lottery']);
    final qrData = _str(e?['qrData']);
    final merchantTin = _str(e?['merchantTin']);
    final posNo = _str(e?['posNo']);

    final b = StringBuffer()
      ..writeln('Баримт')
      ..writeln('Захиалгын дугаар: $orderNumber')
      ..writeln('Огноо: $date')
      ..writeln('Төлбөрийн хэлбэр: $_paymentMethodName')
      ..writeln('')
      ..writeln('Нийт төлсөн: ${_fmtMnt(total)}')
      ..writeln('НӨАТ: ${_fmtMnt(vatAmount)}');

    if (e != null) {
      b
        ..writeln('')
        ..writeln('И-Баримтын мэдээлэл')
        ..writeln('ДДТД: $ddtd')
        ..writeln('ТТД: $merchantTin')
        ..writeln('Касс: $posNo')
        ..writeln('НӨАТ-гүй дүн: ${_fmtMnt(totalNoatgui)}')
        ..writeln('НӨАТ: ${_fmtMnt(totalVat)}')
        ..writeln('НХАТ: ${_fmtMnt(totalCityTax)}')
        ..writeln('Төлөх дүн: ${_fmtMnt(totalAmount)}');
      if (lottery.isNotEmpty) {
        b.writeln('Сугалааны дугаар: $lottery');
      }
      if (qrData.isNotEmpty) {
        b.writeln('QR: $qrData');
      }
    }

    final text = b.toString().trimRight();
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _printEbarimt(Map<String, dynamic>? data) async {
    final e = data;
    if (e == null) return;
    final totalAmount =
        _num(e['amount']) > 0 ? _num(e['amount']) : _num(e['totalAmount']);
    final totalVat = _num(e['vat']) > 0 ? _num(e['vat']) : _num(e['totalVAT']);
    final totalCityTax =
        _num(e['cityTax']) > 0 ? _num(e['cityTax']) : _num(e['totalCityTax']);
    final totalNoatgui = totalAmount - totalVat - totalCityTax;
    final ddtd =
        _str(e['billId']).isNotEmpty ? _str(e['billId']) : _str(e['id']);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('E-BARIMT'),
            pw.SizedBox(height: 8),
            pw.Text('Order: $orderNumber'),
            pw.Text('DDTD: $ddtd'),
            pw.Text('TIN: ${_str(e['merchantTin'])}'),
            pw.Text('POS: ${_str(e['posNo'])}'),
            pw.Text('Amount: ${totalAmount.toStringAsFixed(2)}'),
            pw.Text('Noatgui: ${totalNoatgui.toStringAsFixed(2)}'),
            pw.Text('VAT: ${totalVat.toStringAsFixed(2)}'),
            pw.Text('City tax: ${totalCityTax.toStringAsFixed(2)}'),
            if (_str(e['lottery']).isNotEmpty)
              pw.Text('Lottery: ${_str(e['lottery'])}'),
            if (_str(e['qrData']).isNotEmpty)
              pw.Text('QR: ${_str(e['qrData'])}'),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  Future<Map<String, dynamic>?> _createEbarimtFromDialog(
    BuildContext context,
  ) async {
    if (guilgeeMongoId == null ||
        baiguullagiinId == null ||
        salbariinId == null ||
        guilgeeMongoId!.isEmpty ||
        baiguullagiinId!.isEmpty ||
        salbariinId!.isEmpty) {
      return null;
    }
    var type = 'irgen';
    final registerController = TextEditingController();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setModalState) {
            final isAAN = type == 'aan';
            final kb = MediaQuery.of(ctx2).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + kb),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'И-Баримт үүсгэх',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'irgen', label: Text('Иргэн')),
                      ButtonSegment(value: 'aan', label: Text('ААН')),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) {
                      setModalState(() {
                        type = s.first;
                        if (type == 'irgen') {
                          registerController.clear();
                        }
                      });
                    },
                  ),
                  if (isAAN) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: registerController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'ААН регистр (7 орон)',
                        hintText: '1234567',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final reg = registerController.text.trim().toUpperCase();
                      if (isAAN && reg.length != 7) {
                        ScaffoldMessenger.of(ctx2).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('ААН регистр 7 оронтой байх ёстой')),
                        );
                        return;
                      }
                      final res =
                          await PosTransactionService().requestEbarimtAfterSale(
                        guilgeeniiMongoId: guilgeeMongoId!,
                        baiguullagiinId: baiguullagiinId!,
                        salbariinId: salbariinId!,
                        register: isAAN ? reg : '',
                        turul: isAAN ? '3' : null,
                        customerTin: isAAN ? reg : null,
                      );
                      if (ctx2.mounted) Navigator.pop(ctx2, res);
                    },
                    child: const Text('Үүсгээд хэвлэх'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    registerController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
                    const SizedBox(height: 32),

                    // Receipt Card
                    Container(
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
                                ...items.map(
                                    (item) => _buildReceiptItem(context, item)),

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
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      Text(
                                        _fmtMnt(total),
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onPrimaryContainer,
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
                                        : MongolianDateFormatter.formatDateTime(
                                            DateTime.now(),
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                      context, 'Баримтын дугаар', orderNumber),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(context, 'Төрөл', ebarimtType),
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
                          onPressed: () => _printEbarimt(ebarimt),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('И-Баримт хэвлэх'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (guilgeeMongoId != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final created =
                                await _createEbarimtFromDialog(context);
                            if (created == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('И-Баримт үүсгэхэд амжилтгүй')),
                                );
                              }
                              return;
                            }
                            await _printEbarimt(created);
                          },
                          icon: const Icon(Icons.receipt_long_outlined),
                          label:
                              const Text('Иргэн / ААН И-Баримт үүсгээд хэвлэх'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await _shareReceipt(context);
                          } catch (_) {
                            await Clipboard.setData(
                              ClipboardData(
                                text:
                                    'Баримт: $orderNumber · $_paymentMethodName · ${_fmtMnt(total)}',
                              ),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Хуваалцах боломжгүй тул баримт clipboard-д хууллаа'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Баримт хуваалцах'),
                      ),
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
