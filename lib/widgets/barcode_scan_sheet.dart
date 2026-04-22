import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen bottom sheet: camera barcode → raw string (trimmed), or null if cancelled.
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
      var handled = false;

      final size = MediaQuery.sizeOf(context);
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
                  fit: BoxFit.cover,
                  onDetect: (capture) async {
                    if (handled) return;
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final b = barcodes.first;
                    final raw = (b.rawValue ?? b.displayValue)?.trim();
                    if (raw == null || raw.isEmpty) return;
                    handled = true;
                    await controller.stop();
                    if (context.mounted) Navigator.pop(context, raw);
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      IconButton.filled(
                        onPressed: () => Navigator.pop(context, null),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.black.withValues(alpha: 0.55),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Баркод уншуулна уу',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton.filled(
                        onPressed: () async {
                          try {
                            await controller.toggleTorch();
                          } catch (_) {}
                        },
                        style: IconButton.styleFrom(
                          backgroundColor:
                              Colors.black.withValues(alpha: 0.55),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.flash_on_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Text(
                      'Код автоматаар хайлт руу орно',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 260,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.9),
                      width: 2,
                    ),
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
