import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/printer_service.dart';
import '../utils/mnt_amount_formatter.dart';
import '../utils/thermal_receipt_image.dart';

/// Renders pixel-perfect visual E-Barimt receipt matching [ReceiptScreen]
/// and prints as high-contrast PNG bitmap image on POS terminal.
class VisualReceiptRenderer {
  static const double _paperWidth = 380.0;

  static String _fmt(double v) => MntAmountFormatter.formatTugrik(v);

  /// e-barimt API / printer may use different keys for the QR payload — mirrors
  /// [ReceiptScreen]'s `_qrDataFromEbarimt` so remote prints match the local ones.
  static String _qrDataFromBarimt(Map<String, dynamic> data) {
    for (final key in const [
      'qrData',
      'qr_data',
      'QRData',
      'qr',
      'qrCode',
      'qrString',
    ]) {
      final s = (data[key] ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    final lottery = (data['lottery'] ?? data['lotteryNo'] ?? '').toString().trim();
    if (lottery.isNotEmpty) return 'lottery:$lottery';
    final ddtd = (data['ddtd'] ?? data['billId'] ?? data['id'] ?? '').toString().trim();
    if (ddtd.isNotEmpty) return 'ddtd:$ddtd';
    return '';
  }

  static Future<PrinterResult> printReceiptData(
    BuildContext context,
    Map<String, dynamic> data, {
    String initiatorNer = '',
  }) async {
    final GlobalKey printKey = GlobalKey();
    final Completer<Uint8List> completer = Completer<Uint8List>();

    // Extract receipt fields from signal payload
    final orderNo = (data['orderNumber'] ?? '').toString();
    final cashier = initiatorNer.isNotEmpty ? initiatorNer : 'Кассчин';
    final nowStr = DateTime.now().toString().substring(0, 16);

    final rawTotal = data['totalAmount'];
    double totalVal = 0;
    final itemsList = <Map<String, dynamic>>[];

    final rawItems = data['items'];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) {
          final mapItem = Map<String, dynamic>.from(it);
          itemsList.add(mapItem);
          final p = (mapItem['sumPrice'] ?? mapItem['price'] ?? 0);
          if (p is num) totalVal += p.toDouble();
        }
      }
    }
    if (rawTotal is num && rawTotal > 0) totalVal = rawTotal.toDouble();

    final noatVal = (data['vat'] ?? (totalVal / 11)).toDouble();
    final noatguiVal = totalVal - noatVal;

    final payMethod = (data['paymentMethod'] ?? 'cash').toString().toLowerCase();
    final payMethodLabel = payMethod == 'card'
        ? 'Картаар'
        : payMethod == 'qpay'
            ? 'QPay'
            : 'Бэлэн мөнгө';

    final lottery = (data['lottery'] ?? data['lotteryNo'] ?? '').toString().trim();
    final ddtd = (data['ddtd'] ?? data['billId'] ?? data['id'] ?? '').toString().trim();
    final register = (data['register'] ?? '').toString().trim();
    final companyNer = (data['baiguullagiinNer'] ?? data['companyDisplayName'] ?? '').toString().trim();
    final qrData = _qrDataFromBarimt(data);

    // Check if E-Barimt 3.0 system is enabled / active for this receipt
    final bool isEbarimtActive = (data['eBarimtShine'] == true) ||
        (data['hasEbarimt'] == true) ||
        (data['ebarimt'] != null) ||
        lottery.isNotEmpty ||
        ddtd.isNotEmpty ||
        qrData.isNotEmpty;

    // Check if NHAT (City Tax) is enabled on items or amount
    final double nhatVal = (data['nhat'] ?? data['cityTax'] ?? 0).toDouble();
    final bool hasItemNhat = itemsList.any((i) => i['nhatBodohEsekh'] == true || (i['nhatiinDun'] ?? 0) > 0);
    final bool showNhat = nhatVal > 0 || hasItemNhat;

    // Create offscreen widget overlay
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (BuildContext ctx) {
        // Capture frame after first paint
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await Future.delayed(const Duration(milliseconds: 150));
            final boundary = printKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
            if (boundary != null) {
              final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
              final Uint8List pngBytes = await encodeThermalReceiptPng(image);
              image.dispose();
              if (!completer.isCompleted) completer.complete(pngBytes);
            } else {
              if (!completer.isCompleted) completer.completeError('Boundary null');
            }
          } catch (e) {
            if (!completer.isCompleted) completer.completeError(e);
          } finally {
            try { overlayEntry.remove(); } catch (_) {}
          }
        });

        return Positioned(
          left: -9999,
          top: -9999,
          child: Material(
            color: Colors.transparent,
            child: RepaintBoundary(
              key: printKey,
              child: Container(
                width: _paperWidth,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: double.infinity,
                      child: Text(
                        'POSEASE БАРИМТ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Касс: $cashier',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'БД: $orderNo',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Огноо: $nowStr',
                      style: const TextStyle(color: Colors.black, fontSize: 13),
                    ),
                    if (isEbarimtActive && ddtd.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('ДДТД: $ddtd', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                    if (register.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Регистр: $register', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                    if (companyNer.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Худалдан авагч: $companyNer', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                    const SizedBox(height: 4),
                    const Text('----------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 10)),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Expanded(child: Text('Бараа', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14))),
                        SizedBox(width: 60, child: Text('Тоо', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14))),
                        SizedBox(width: 90, child: Text('Үнэ', textAlign: TextAlign.right, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('----------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 10)),
                    const SizedBox(height: 4),
                    for (final item in itemsList) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                (item['name'] ?? 'Бараа').toString(),
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                                maxLines: 2,
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                'x${item['count'] ?? 1}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            SizedBox(
                              width: 90,
                              child: Text(
                                _fmt((item['sumPrice'] ?? item['price'] ?? 0).toDouble()),
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text('----------------------------------------------', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 10)),
                    const SizedBox(height: 4),
                    _moneyRow('Төлбөр', payMethodLabel, isTitle: true),
                    _moneyRow('Нийт дүн', _fmt(totalVal)),
                    if (isEbarimtActive) ...[
                      _moneyRow('НӨАТ-гүй дүн', _fmt(noatguiVal)),
                      _moneyRow('НӨАТ', _fmt(noatVal)),
                    ],
                    if (showNhat)
                      _moneyRow('НХАТ', _fmt(nhatVal)),
                    _moneyRow('Төлөх дүн', _fmt(totalVal), isBold: true),
                    if (isEbarimtActive)
                      _moneyRow('И-Баримт дүн', _fmt(totalVal), isBold: true),
                    if (isEbarimtActive && lottery.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Сугалааны дугаар: $lottery',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          if (isEbarimtActive && qrData.isNotEmpty) ...[
                            QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'QR уншуулаад баримтаа шалгана уу',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                          ],
                          const Text(
                            'Баярлалаа!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    try {
      Overlay.of(context).insert(overlayEntry);
    } catch (_) {
      return const PrinterResult(
        success: false,
        backend: 'none',
        message: 'Overlay error',
      );
    }

    try {
      final pngBytes = await completer.future.timeout(const Duration(seconds: 4));
      return await PrinterService.printReceiptImage(
        pngBytes,
        amount: totalVal,
        dbRefNo: ddtd.isNotEmpty ? ddtd : orderNo,
      );
    } catch (e) {
      return PrinterResult(
        success: false,
        backend: 'none',
        message: 'Visual receipt render error: $e',
      );
    }
  }

  static Widget _moneyRow(String label, String value, {bool isBold = false, bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontWeight: isBold || isTitle ? FontWeight.w800 : FontWeight.w500,
              fontSize: isTitle ? 16 : (isBold ? 15 : 14),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Colors.black,
              fontWeight: isBold || isTitle ? FontWeight.w900 : FontWeight.w700,
              fontSize: isTitle ? 16 : (isBold ? 15 : 14),
            ),
          ),
        ],
      ),
    );
  }
}
