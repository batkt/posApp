import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Helper to render product label graphics for Niimbot B1 printing
class NiimbotLabelBuilder {
  /// Default B1 label paper pixel dimensions at 203 DPI:
  /// Width: 384 pixels (~48mm)
  /// Height: 240 pixels (~30mm)
  static Future<Uint8List> generateProductLabelImage({
    required String title,
    required String priceText,
    String? barcodeOrSku,
    String storeName = 'POSEASE',
    int width = 384,
    int height = 240,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // 1. White Background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

    // 2. High-contrast Black Border (0.5mm)
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(Rect.fromLTWH(4, 4, width - 8, height - 8), borderPaint);

    // 3. Header / Store Name
    const headerStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.1,
    );
    final headerPainter = TextPainter(
      text: TextSpan(text: storeName.toUpperCase(), style: headerStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 20);
    headerPainter.paint(canvas, Offset((width - headerPainter.width) / 2, 12));

    // Divider Line
    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(12, 32), Offset(width - 12, 32), linePaint);

    // 4. Product Title (Max 2 lines)
    const titleStyle = TextStyle(
      color: Colors.black,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: width - 110);
    titlePainter.paint(canvas, const Offset(16, 40));

    // 5. Price
    const priceStyle = TextStyle(
      color: Colors.black,
      fontSize: 22,
      fontWeight: FontWeight.w900,
    );
    final pricePainter = TextPainter(
      text: TextSpan(text: priceText, style: priceStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 110);
    pricePainter.paint(canvas, const Offset(16, 92));

    // 6. SKU / Barcode text
    if (barcodeOrSku != null && barcodeOrSku.trim().isNotEmpty) {
      const skuStyle = TextStyle(
        color: Colors.black,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFamily: 'monospace',
      );
      final skuPainter = TextPainter(
        text: TextSpan(text: 'SKU: ${barcodeOrSku.trim()}', style: skuStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 110);
      skuPainter.paint(canvas, const Offset(16, 128));

      // Draw QR Code on the right side if SKU present
      try {
        final qrValidationResult = QrValidator.validate(
          data: barcodeOrSku.trim(),
          version: QrVersions.auto,
          errorCorrectionLevel: QrErrorCorrectLevel.L,
        );
        if (qrValidationResult.status == QrValidationStatus.valid) {
          final qrCode = qrValidationResult.qrCode!;
          final qrPainter = QrPainter.withQr(
            qr: qrCode,
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            gapless: true,
          );
          const qrSize = 90.0;
          final qrOffset = Offset(width - qrSize - 16, 42);
          canvas.save();
          canvas.translate(qrOffset.dx, qrOffset.dy);
          qrPainter.paint(canvas, const Size(qrSize, qrSize));
          canvas.restore();
        }
      } catch (_) {}
    }

    // 7. Footer line
    canvas.drawLine(Offset(12, height - 24), Offset(width - 12, height - 24), linePaint);
    const footerStyle = TextStyle(
      color: Colors.black,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    final footerPainter = TextPainter(
      text: const TextSpan(text: 'NIIMBOT B1 • 40x30mm Label', style: footerStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 20);
    footerPainter.paint(canvas, Offset((width - footerPainter.width) / 2, height - 20));

    // End Recording & Convert to Image PNG Bytes
    final picture = recorder.endRecording();
    final imgObj = await picture.toImage(width, height);
    final byteData = await imgObj.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
