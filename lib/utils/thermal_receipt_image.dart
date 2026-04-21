import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Typical 58mm thermal head width in dots; downscale avoids fuzzy driver scaling.
const int _thermalTargetWidthPx = 384;

/// Pixels darker than this (0–255 luminance) become black on the receipt.
const double _luminanceBlackBelow = 172;

/// Converts a captured receipt [image] to a high-contrast PNG for thermal printers.
/// Anti-aliased gray text becomes solid black; background becomes solid white.
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

  final dst = Uint8List(work.length);
  for (var i = 0; i < work.length; i += 4) {
    final a = work[i + 3];
    if (a < 28) {
      dst[i] = 255;
      dst[i + 1] = 255;
      dst[i + 2] = 255;
      dst[i + 3] = 255;
      continue;
    }
    final r = work[i];
    final g = work[i + 1];
    final b = work[i + 2];
    final lum = 0.299 * r + 0.587 * g + 0.114 * b;
    final ink = lum < _luminanceBlackBelow ? 0 : 255;
    dst[i] = ink;
    dst[i + 1] = ink;
    dst[i + 2] = ink;
    dst[i + 3] = 255;
  }

  final outImage = await _imageFromRgba(dst, outW, outH);
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
