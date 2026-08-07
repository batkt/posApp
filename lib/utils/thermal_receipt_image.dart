import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Typical 58mm thermal head width in dots; downscale avoids fuzzy driver scaling.
const int _thermalTargetWidthPx = 384;

/// Pixels darker than this (0–255 luminance) become black on the receipt.
const double _luminanceBlackBelow = 210;

/// Converts a captured receipt [image] to a high-contrast PNG for thermal printers.
/// Optimized using Uint32List view & integer math for zero CPU/RAM stutter on Android POS.
Future<Uint8List> encodeThermalReceiptPng(ui.Image image) async {
  final w = image.width;
  final h = image.height;
  final bd = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  if (bd == null) {
    throw StateError('Receipt image toByteData failed');
  }
  final src = bd.buffer.asUint8List();

  var outW = w;
  var outH = h;
  var work = src;

  if (w > _thermalTargetWidthPx) {
    outW = _thermalTargetWidthPx;
    outH = (h * (outW / w)).round().clamp(1, 1 << 20);
    work = Uint8List(outW * outH * 4);
    _boxDownsampleRgba(src, w, h, work, outW, outH);
  }

  final Uint32List pixels32 = work.buffer.asUint32List();
  final int len = pixels32.length;
  final Uint32List dst32 = Uint32List(len);

  // ABGR 32-bit pixel packing for raw straight RGBA buffer
  const int blackPixel = 0xFF000000;
  const int whitePixel = 0xFFFFFFFF;
  final int threshold = (_luminanceBlackBelow * 1000).toInt();

  for (var i = 0; i < len; i++) {
    final int pixel = pixels32[i];
    final int a = (pixel >> 24) & 0xFF;
    if (a < 28) {
      dst32[i] = whitePixel;
      continue;
    }
    final int r = pixel & 0xFF;
    final int g = (pixel >> 8) & 0xFF;
    final int b = (pixel >> 16) & 0xFF;
    final int lum1000 = r * 299 + g * 587 + b * 114;
    dst32[i] = lum1000 < threshold ? blackPixel : whitePixel;
  }

  final outImage = await _imageFromRgba(dst32.buffer.asUint8List(), outW, outH);
  try {
    final png = await outImage.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw StateError('PNG encode failed');
    }
    return png.buffer.asUint8List();
  } finally {
    outImage.dispose();
  }
}

Future<ui.Image> _imageFromRgba(Uint8List rgba, int width, int height) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    (ui.Image img) {
      if (!c.isCompleted) {
        c.complete(img);
      }
    },
  );
  return c.future;
}

/// Fast box downsample (average 2×2 blocks) to reduce width; improves thermal clarity.
void _boxDownsampleRgba(
  Uint8List src,
  int sw,
  int sh,
  Uint8List dst,
  int dw,
  int dh,
) {
  final xRatio = sw / dw;
  final yRatio = sh / dh;
  for (var dy = 0; dy < dh; dy++) {
    final y0 = (dy * yRatio).floor();
    var y1 = ((dy + 1) * yRatio).ceil();
    if (y1 > sh) y1 = sh;
    if (y1 <= y0) continue;
    for (var dx = 0; dx < dw; dx++) {
      final x0 = (dx * xRatio).floor();
      var x1 = ((dx + 1) * xRatio).ceil();
      if (x1 > sw) x1 = sw;
      if (x1 <= x0) continue;
      var sr = 0, sg = 0, sb = 0, sa = 0, cnt = 0;
      for (var y = y0; y < y1; y++) {
        final row = y * sw * 4;
        for (var x = x0; x < x1; x++) {
          final o = row + x * 4;
          sr += src[o];
          sg += src[o + 1];
          sb += src[o + 2];
          sa += src[o + 3];
          cnt++;
        }
      }
      if (cnt == 0) continue;
      final o = (dy * dw + dx) * 4;
      dst[o] = (sr / cnt).round().clamp(0, 255);
      dst[o + 1] = (sg / cnt).round().clamp(0, 255);
      dst[o + 2] = (sb / cnt).round().clamp(0, 255);
      dst[o + 3] = (sa / cnt).round().clamp(0, 255);
    }
  }
}
