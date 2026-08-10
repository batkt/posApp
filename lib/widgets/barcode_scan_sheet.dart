import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/inventory_model.dart';

/// Pool of pre-loaded players for the scan beep, shared across both sheets below.
/// A single reused [AudioPlayer] only reliably plays once — [AudioPool] is the
/// package's documented way to handle "extremely quick firing, repetitive" sounds.
Future<AudioPool>? _scanBeepPoolFuture;

Future<AudioPool> _getScanBeepPool() {
  return _scanBeepPoolFuture ??= AudioPool.createFromAsset(
    path: 'sounds/beep.wav',
    minPlayers: 2,
    maxPlayers: 4,
  );
}

void _playScanBeep() {
  () async {
    try {
      final pool = await _getScanBeepPool();
      await pool.start();
    } catch (e) {
      debugPrint('barcode_scan_sheet: beep playback failed: $e');
    }
  }();
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE-SCAN SHEET  (used by Inventory, Toololt, etc.)
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen camera barcode → returns single raw barcode string (trimmed), or null if cancelled.
Future<String?> showBarcodeScanSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final controller = MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
      final size = MediaQuery.sizeOf(context);
      var handled = false;
      final topInset = MediaQuery.paddingOf(context).top;
      const scanBoxWidth = 280.0;
      const scanBoxHeight = 160.0;
      final scanBoxTop = topInset + 88.0;
      final scanBoxLeft = (size.width - scanBoxWidth) / 2;
      final scanWindowRect = Rect.fromLTWH(
        scanBoxLeft,
        scanBoxTop,
        scanBoxWidth,
        scanBoxHeight,
      );

      return SizedBox(
        height: size.height,
        width: size.width,
        child: Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: MobileScanner(
                  controller: controller,
                  scanWindow: scanWindowRect,
                  fit: BoxFit.cover,
                  onDetect: (capture) async {
                    if (handled) return;
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final b = barcodes.first;
                    final raw = (b.rawValue ?? b.displayValue)?.trim();
                    if (raw == null || raw.isEmpty) return;
                    handled = true;
                    _playScanBeep();
                    await controller.stop();
                    if (context.mounted) Navigator.pop(context, raw);
                  },
                ),
              ),
              Positioned(
                top: scanBoxTop,
                left: scanBoxLeft,
                child: Container(
                  width: scanBoxWidth,
                  height: scanBoxHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.primary,
                      width: 3.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  alignment: Alignment.bottomCenter,
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Баркод энэ хүрээнд байрлуулна уу',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(14, topInset + 8, 14, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.90),
                        Colors.black.withValues(alpha: 0.50),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton.filled(
                        onPressed: () => Navigator.pop(context, null),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.55),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Баркод уншуулна уу',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton.filled(
                        onPressed: () async {
                          try { await controller.toggleTorch(); } catch (_) {}
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.55),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.flash_on_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BATCH MULTI-SCAN SHEET  (scan inside target box → preview list → Checkout)
// ─────────────────────────────────────────────────────────────────────────────

/// One line item in the batch scanner; quantity can be adjusted with +/− buttons.
class BatchScanItem {
  final InventoryItem item;
  int quantity;
  BatchScanItem({required this.item, this.quantity = 1});
}

/// Opens a full-screen rapid-scan sheet with scanWindow restricted strictly inside
/// the target box.
///
/// Each scanned barcode is resolved via [findProduct]. Matching items appear in
/// a preview list below the camera view. The user may adjust quantities and
/// then press "Борлуулалт ба төлбөр" to confirm.
///
/// Returns the confirmed [BatchScanItem] list, or null / empty if cancelled.
Future<List<BatchScanItem>?> showBarcodeQuickScanSheet(
  BuildContext context, {
  required InventoryItem? Function(String barcode) findProduct,
}) {
  return showModalBottomSheet<List<BatchScanItem>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuickScanSheet(findProduct: findProduct),
  );
}

// ─── internal StatefulWidget ─────────────────────────────────────────────────

class _QuickScanSheet extends StatefulWidget {
  const _QuickScanSheet({required this.findProduct});
  final InventoryItem? Function(String barcode) findProduct;

  @override
  State<_QuickScanSheet> createState() => _QuickScanSheetState();
}

class _QuickScanSheetState extends State<_QuickScanSheet> {
  late final MobileScannerController _controller;

  /// Ordered batch: productId → item + qty (linked map preserves insertion order).
  final Map<String, BatchScanItem> _batch = {};

  static const _cooldownMs = 1200;
  final Map<String, int> _lastScanTime = {};

  bool _torchOn = false;
  String? _feedbackText;
  bool _feedbackError = false;

  int get _totalPieces =>
      _batch.values.fold(0, (s, e) => s + e.quantity);

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── scan handling ────────────────────────────────────────────────────────

  void _handleDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final raw =
        (capture.barcodes.first.rawValue ?? capture.barcodes.first.displayValue)
            ?.trim();
    if (raw == null || raw.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if ((now - (_lastScanTime[raw] ?? 0)) < _cooldownMs) return;
    _lastScanTime[raw] = now;
    _playScanBeep();

    final found = widget.findProduct(raw);
    if (found == null) {
      _flash('Олдсонгүй: $raw', error: true);
      return;
    }

    setState(() {
      if (_batch.containsKey(found.product.id)) {
        final entry = _batch[found.product.id]!;
        final maxStock = found.currentStock;
        if (entry.quantity >= maxStock && maxStock > 0) {
          _flash('${found.product.name} — Нөөц дуусав', error: true);
          return;
        }
        entry.quantity++;
      } else {
        if (found.currentStock <= 0) {
          _flash('${found.product.name} — Дууссан', error: true);
          return;
        }
        _batch[found.product.id] = BatchScanItem(item: found);
      }
    });
    _flash('+1  ${found.product.name}', error: false);
  }

  void _flash(String text, {required bool error}) {
    setState(() {
      _feedbackText = text;
      _feedbackError = error;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  // ── quantity helpers ─────────────────────────────────────────────────────

  void _increment(String productId) => setState(() {
        _batch[productId]?.quantity++;
      });

  void _decrement(String productId) => setState(() {
        final e = _batch[productId];
        if (e == null) return;
        if (e.quantity <= 1) {
          _batch.remove(productId);
        } else {
          e.quantity--;
        }
      });

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final items = _batch.values.toList();
    final hasItems = items.isNotEmpty;

    final topInset = MediaQuery.paddingOf(context).top;
    const scanBoxWidth = 280.0;
    const scanBoxHeight = 160.0;
    final scanBoxTop = topInset + 88.0;
    final scanBoxLeft = (size.width - scanBoxWidth) / 2;
    final scanWindowRect = Rect.fromLTWH(
      scanBoxLeft,
      scanBoxTop,
      scanBoxWidth,
      scanBoxHeight,
    );

    return SizedBox(
      height: size.height,
      width: size.width,
      child: Material(
        color: Colors.black,
        child: Stack(
          children: [
            // ── Camera with strict scanWindow ──────────────────────────────
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                scanWindow: scanWindowRect,
                fit: BoxFit.cover,
                onDetect: _handleDetect,
              ),
            ),

            // ── Bottom gradient overlay ────────────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: size.height * 0.55,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.96),
                    ],
                  ),
                ),
              ),
            ),

            // ── Scan-frame guide box (matches scanWindowRect) ──────────────
            Positioned(
              top: scanBoxTop,
              left: scanBoxLeft,
              child: Container(
                width: scanBoxWidth,
                height: scanBoxHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.primary,
                    width: 3.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Баркод энэ хүрээнд байрлуулна уу',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // ── Top Gradient + Header ─────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(14, topInset + 8, 14, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.90),
                      Colors.black.withValues(alpha: 0.50),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton.filled(
                      onPressed: () => Navigator.pop(context, null),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Хурдан скан',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            hasItems
                                ? '${items.length} төрөл · $_totalPieces ширхэг нэмэгдлээ'
                                : 'Баркод уншуулахад жагсаалтад нэмэгдэнэ',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () async {
                        try {
                          await _controller.toggleTorch();
                          setState(() => _torchOn = !_torchOn);
                        } catch (_) {}
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: _torchOn
                            ? Colors.amber.withValues(alpha: 0.85)
                            : Colors.black.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        _torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Feedback banner ───────────────────────────────────────────
            if (_feedbackText != null)
              Positioned(
                top: scanBoxTop + scanBoxHeight + 12,
                left: 20,
                right: 20,
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _feedbackError
                          ? Colors.red.shade700.withValues(alpha: 0.9)
                          : Colors.green.shade700.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _feedbackError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _feedbackText!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Product list + action button ──────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Scanned items list
                    if (hasItems) ...[
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shopping_cart_rounded,
                              color: Colors.white54,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Сагс  —  $_totalPieces ширхэг',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: size.height * 0.36,
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final entry = items[i];
                            return Container(
                              height: 50,
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          entry.item.product.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (entry.item.product.code != null)
                                          Text(
                                            entry.item.product.code!,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _QtyButton(
                                    icon: Icons.remove_rounded,
                                    onTap: () =>
                                        _decrement(entry.item.product.id),
                                  ),
                                  SizedBox(
                                    width: 34,
                                    child: Text(
                                      '${entry.quantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  _QtyButton(
                                    icon: Icons.add_rounded,
                                    onTap: () =>
                                        _increment(entry.item.product.id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Checkout / placeholder button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: hasItems
                              ? () => Navigator.pop(context, items)
                              : null,
                          icon: const Icon(Icons.payment_rounded),
                          label: Text(
                            hasItems
                                ? 'Борлуулалт ба төлбөр  ·  $_totalPieces ширхэг'
                                : 'Баркод уншуулна уу',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                hasItems ? cs.primary : Colors.white24,
                            foregroundColor:
                                hasItems ? cs.onPrimary : Colors.white54,
                            disabledBackgroundColor: Colors.white24,
                            disabledForegroundColor: Colors.white54,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
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
}

// ── small helper widget ───────────────────────────────────────────────────────

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
