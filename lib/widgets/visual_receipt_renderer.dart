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
    return '';
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0.0;
  }

  static Widget buildVisualReceiptWidget(
    Map<String, dynamic> data, {
    String initiatorNer = '',
  }) {
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
          totalVal += _toDouble(p);
        }
      }
    }
    final parsedRawTotal = _toDouble(rawTotal);
    if (parsedRawTotal > 0) totalVal = parsedRawTotal;

    final double noatVal = data['vat'] != null ? _toDouble(data['vat']) : 0.0;
    final noatguiVal = totalVal - noatVal;

    final payMethod = (data['paymentMethod'] ?? 'cash').toString().toLowerCase();
    final payMethodLabel = payMethod == 'card'
        ? 'Картаар'
        : payMethod == 'qpay'
            ? 'QPay'
            : 'Бэлэн мөнгө';

    final lottery = (data['lottery'] ?? data['lotteryNo'] ?? '').toString().trim();
    final billId = (data['billId'] ?? data['ddtd'] ?? '').toString().trim();
    final register = (data['register'] ?? '').toString().trim();
    final companyNer = (data['baiguullagiinNer'] ?? data['merchantName'] ?? '').toString().trim();
    final buyerCompanyNer = (data['customerName'] ?? data['companyDisplayName'] ?? data['buyerName'] ?? '').toString().trim();
    final qrData = _qrDataFromBarimt(data);

    final bool isEbarimtActive = (data['eBarimtShine'] == true) &&
        ((data['hasEbarimt'] == true) ||
            (data['ebarimt'] != null) ||
            lottery.isNotEmpty ||
            (qrData.isNotEmpty && !qrData.startsWith('ddtd:')));

    final double nhatVal = _toDouble(data['nhat'] ?? data['cityTax'] ?? 0);
    final bool hasItemNhat = itemsList.any((i) => i['nhatBodohEsekh'] == true || _toDouble(i['nhatiinDun']) > 0);
    final bool showNhat = nhatVal > 0 || hasItemNhat;

    const thermalDashLine = Text(
      '----------------------------------------------',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.black,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        height: 1.0,
      ),
    );

    return Container(
      width: _paperWidth,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Text(
              '${companyNer.isNotEmpty ? companyNer.toUpperCase() : 'POSEASE'} БАРИМТ',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                fontSize: 18,
              ),
            ),
          ),
          (() {
            final salbarNer = (data['salbarNer'] ?? data['salbariinNer'] ?? data['salbarName'] ?? data['salbar'] ?? '').toString().trim();
            final displaySalbar = salbarNer.isNotEmpty ? salbarNer : companyNer;
            if (displaySalbar.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Салбар: $displaySalbar',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            );
          })(),
          if (cashier.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Касс: $cashier',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            'БД: $orderNo',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            nowStr,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (isEbarimtActive && billId.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'ДДТД: $billId',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          if (register.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Регистр: $register',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          if (buyerCompanyNer.isNotEmpty && buyerCompanyNer != companyNer) ...[
            const SizedBox(height: 2),
            Text(
              'Худалдан авагч: $buyerCompanyNer',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 1),
          thermalDashLine,
          const SizedBox(
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Бараа',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(
                  width: 76,
                  height: 14,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      'Тоо ширхэг',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Text(
                    'Үнэ',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          for (final item in itemsList) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (() {
                        final rawName = (item['name'] ?? item['ner'] ?? 'Бараа').toString();
                        final hasMultipleBranches = itemsList.map((i) => (i['salbariinId'] ?? i['salbarNer'] ?? i['salbar'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().length > 1;
                        final salbarStr = (item['salbarNer'] ?? item['salbariinNer'] ?? item['salbar'] ?? '').toString();
                        if (hasMultipleBranches && salbarStr.isNotEmpty && !rawName.contains('($salbarStr)')) {
                          return '$rawName ($salbarStr)';
                        }
                        return rawName;
                      })(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 76,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${item['count'] ?? 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      _fmt(_toDouble(item['sumPrice'] ?? item['price'] ?? 0)),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          thermalDashLine,
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                const Text(
                  'Төлбөр',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                Text(
                  payMethodLabel,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          _moneyRow('Нийт дүн', _fmt(totalVal), fontSize: 15, isBold: true),
          if (isEbarimtActive && noatVal > 0) ...[
            _moneyRow('НӨАТ-гүй дүн', _fmt(noatguiVal), fontSize: 14, isBold: true),
            _moneyRow('НӨАТ', _fmt(noatVal), fontSize: 14, isBold: true),
          ],
          if (showNhat)
            _moneyRow('НХАТ', _fmt(nhatVal), fontSize: 14, isBold: true),
          _moneyRow('Төлөх дүн', _fmt(totalVal), fontSize: 16, isBold: true),
          if (isEbarimtActive)
            _moneyRow('И-Баримт дүн', _fmt(totalVal), fontSize: 16, isBold: true),
          if (isEbarimtActive && lottery.isNotEmpty) ...[
            const SizedBox(height: 4),
            thermalDashLine,
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  'Сугалааны дугаар: $lottery',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isEbarimtActive && qrData.isNotEmpty) ...[
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
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'QR уншуулаад баримтаа шалгана уу',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
                const Text(
                  'Баярлалаа',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<PrinterResult> printReceiptData(
    BuildContext context,
    Map<String, dynamic> data, {
    String initiatorNer = '',
  }) async {
    final rawTotal = data['totalAmount'];
    double totalVal = 0;
    if (data['items'] is List) {
      for (final it in data['items']) {
        if (it is Map) {
          final p = (it['sumPrice'] ?? it['price'] ?? 0);
          totalVal += _toDouble(p);
        }
      }
    }
    final parsedRawTotal = _toDouble(rawTotal);
    if (parsedRawTotal > 0) totalVal = parsedRawTotal;
    final orderNo = (data['orderNumber'] ?? '').toString();
    final ddtd = (data['ddtd'] ?? data['billId'] ?? data['id'] ?? '').toString().trim();

    try {
      final widget = buildVisualReceiptWidget(data, initiatorNer: initiatorNer);
      final Uint8List pngBytes = await renderWidgetToThermalPng(widget);

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

  /// Renders a Flutter [Widget] to thermal-binarized PNG bytes using an offscreen PipelineOwner.
  static Future<Uint8List> renderWidgetToThermalPng(
    Widget widget, {
    double width = 380.0,
    double estimatedHeight = 1200.0,
  }) async {
    final RenderRepaintBoundary repaintBoundary = RenderRepaintBoundary();
    final RenderView renderView = RenderView(
      view: ui.PlatformDispatcher.instance.implicitView!,
      child: RenderPositionedBox(alignment: Alignment.topCenter, child: repaintBoundary),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints(
          minWidth: width,
          maxWidth: width,
          minHeight: 100,
          maxHeight: estimatedHeight,
        ),
        devicePixelRatio: 3.0,
      ),
    );

    final PipelineOwner pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final BuildOwner buildOwner = BuildOwner(focusManager: FocusManager());
    final RenderObjectToWidgetElement<RenderBox> rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.white,
          child: widget,
        ),
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    final ui.Image image = await repaintBoundary.toImage(pixelRatio: 3.0);
    final Uint8List pngBytes = await encodeThermalReceiptPng(image);
    image.dispose();
    return pngBytes;
  }

  static Widget _moneyRow(String label, String value, {double fontSize = 14, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.black,
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              height: 1.15,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
