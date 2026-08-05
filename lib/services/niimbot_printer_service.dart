import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:image/image.dart' as img;

/// Result object for Niimbot print operations
class NiimbotPrintResult {
  final bool success;
  final String message;
  final String? deviceName;

  const NiimbotPrintResult({
    required this.success,
    required this.message,
    this.deviceName,
  });
}

/// Encoder for NIIMBOT B1 binary packet protocol according to niim.blue community spec
class NiimbotPacketEncoder {
  static const int headerByte = 0x55;
  static const int tailByte = 0xAA;

  /// Build Niimbot 0x55 0x55 frame with XOR checksum and 0xAA 0xAA tail
  static Uint8List buildPacket(int command, List<int> payload, {bool isConnect = false}) {
    final len = payload.length;
    int checksum = command ^ len;
    for (final b in payload) {
      checksum ^= b;
    }

    final builder = BytesBuilder()
      ..addByte(headerByte)
      ..addByte(headerByte)
      ..addByte(command & 0xFF)
      ..addByte(len & 0xFF)
      ..add(payload)
      ..addByte(checksum & 0xFF)
      ..addByte(tailByte)
      ..addByte(tailByte);

    return builder.toBytes();
  }

  /// Connect command (0xC1): [0x55, 0x55, 0xC1, 0x01, 0x01, 0xC1, 0xAA, 0xAA]
  static Uint8List cmdConnect() {
    return buildPacket(0xC1, [0x01]);
  }

  /// PrintClear command (0x20)
  static Uint8List cmdPrintClear() {
    return buildPacket(0x20, [0x01]);
  }

  /// Set print density (0x21), density 1..5 (default 5)
  static Uint8List cmdSetDensity({int density = 5}) {
    return buildPacket(0x21, [density & 0xFF]);
  }

  /// Set label paper type (0x23), 1 = gap paper, 2 = black mark, 3 = continuous
  static Uint8List cmdSetLabelType({int labelType = 1}) {
    return buildPacket(0x23, [labelType & 0xFF]);
  }

  /// Start print job command (0x01) - 7 bytes format: [totalPages_hi, totalPages_lo, 0x00, 0x00, 0x00, 0x00, color]
  static Uint8List cmdStartJob({int totalPages = 1, int color = 0}) {
    return buildPacket(0x01, [
      (totalPages >> 8) & 0xFF,
      totalPages & 0xFF,
      0x00,
      0x00,
      0x00,
      0x00,
      color & 0xFF,
    ]);
  }

  /// Start print page command (0x03)
  static Uint8List cmdStartPage() {
    return buildPacket(0x03, [0x01]);
  }

  /// Set page size command (0x13) - 6 bytes format: [rowsHi, rowsLo, colsHi, colsLo, copiesHi, copiesLo]
  static Uint8List cmdSetPageSize({required int rows, int cols = 384, int copies = 1}) {
    return buildPacket(0x13, [
      (rows >> 8) & 0xFF,
      rows & 0xFF,
      (cols >> 8) & 0xFF,
      cols & 0xFF,
      (copies >> 8) & 0xFF,
      copies & 0xFF,
    ]);
  }

  /// End print page command (0xE3)
  static Uint8List cmdEndPage() {
    return buildPacket(0xE3, [0x01]);
  }

  /// End print job command (0xF3)
  static Uint8List cmdEndJob() {
    return buildPacket(0xF3, [0x01]);
  }

  /// Heartbeat command (0xDC) to reset printer watchdog timer during line streaming
  static Uint8List cmdHeartbeat() {
    return buildPacket(0xDC, [0x01]);
  }

  /// Page Feed command (0xD3) to advance paper to gap / tear bar
  static Uint8List cmdPageFeed() {
    return buildPacket(0xD3, [0x01]);
  }

  /// Print status poll command (0xA3) - response reports page index + progress,
  /// used to confirm the printer actually finished rendering buffered rows before EndJob.
  static Uint8List cmdPrintStatus() {
    return buildPacket(0xA3, [0x01]);
  }

  /// Write monochrome bitmap line packet (0x85)
  /// Format: [lineNoHi, lineNoLo, count0, count1, count2, run, rowBytes...]
  /// The printer firmware gates whether it fires the thermal head for a row on the
  /// count fields, NOT just the bitmap bytes - they must be correct. Mirrors the
  /// niimbluelib "auto" counting mode: rows that fit within 3 equal chunks of the
  /// printhead width are sent as 3 per-third black-pixel counts (split mode);
  /// otherwise a single 16-bit total is sent as [0x00, lowByte, highByte].
  static Uint8List cmdRasterLine(
    int lineIndex,
    List<int> lineBytes, {
    int repeat = 1,
    int printheadPixels = 384,
  }) {
    final payload = <int>[
      (lineIndex >> 8) & 0xFF,
      lineIndex & 0xFF,
      ..._countPixelsForBitmapPacket(lineBytes, printheadPixels),
      repeat & 0xFF,
      ...lineBytes,
    ];
    return buildPacket(0x85, payload);
  }

  static List<int> _countPixelsForBitmapPacket(List<int> lineBytes, int printheadPixels) {
    final chunkSize = (printheadPixels / 8 / 3).floor();
    final bool split = chunkSize > 0 && lineBytes.length <= chunkSize * 3;

    if (!split) {
      int total = 0;
      for (final byte in lineBytes) {
        total += _popCount(byte);
      }
      return [0x00, total & 0xFF, (total >> 8) & 0xFF];
    }

    final parts = [0, 0, 0];
    for (int byteN = 0; byteN < lineBytes.length; byteN++) {
      final chunkIdx = (byteN ~/ chunkSize).clamp(0, 2);
      parts[chunkIdx] += _popCount(lineBytes[byteN]);
    }
    return [parts[0] & 0xFF, parts[1] & 0xFF, parts[2] & 0xFF];
  }

  static int _popCount(int byte) {
    int count = 0;
    int b = byte;
    while (b != 0) {
      count += b & 1;
      b >>= 1;
    }
    return count;
  }
}

/// Service class for scanning, connecting, and printing to NIIMBOT B1 label printers
class NiimbotPrinterService {
  /// B1 thermal printhead max dots width = 384 pixels (~48mm width at 203 DPI)
  static const int maxPrintWidthDots = 384;

  /// Scan for nearby Bluetooth Niimbot devices
  static Stream<List<ScanResult>> scanForPrinters({Duration timeout = const Duration(seconds: 5)}) {
    FlutterBluePlus.startScan(
      timeout: timeout,
      withNames: [],
    );
    return FlutterBluePlus.scanResults;
  }

  /// Stops BLE scanning
  static Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Extracts the best available display name from BLE scan result
  static String getDeviceDisplayName(ScanResult result) {
    if (result.advertisementData.advName.trim().isNotEmpty) {
      return result.advertisementData.advName.trim();
    }
    if (result.device.platformName.trim().isNotEmpty) {
      return result.device.platformName.trim();
    }
    return '';
  }

  /// Check if a scanned device name or result indicates a Niimbot / LCK label printer
  static bool isNiimbotDevice(String name) {
    final clean = name.trim().toUpperCase();
    return clean.contains('NIIMBOT') ||
        clean.contains('LCK') ||
        clean.contains('SA_AE108_') ||
        clean.contains('B1') ||
        clean.contains('B21') ||
        clean.contains('B203') ||
        clean.contains('D11') ||
        clean.contains('D110') ||
        clean.contains('JC-');
  }

  /// Check if a ScanResult represents a Niimbot printer via name or advertised service UUIDs
  static bool isNiimbotScanResult(ScanResult result) {
    final name = getDeviceDisplayName(result);
    if (name.isNotEmpty && isNiimbotDevice(name)) return true;

    for (final serviceUuid in result.advertisementData.serviceUuids) {
      final uuidStr = serviceUuid.toString().toLowerCase();
      if (uuidStr.contains('fff0') ||
          uuidStr.contains('ffe0') ||
          uuidStr.contains('ffe1') ||
          uuidStr.contains('e7810a71') ||
          uuidStr.contains('fee7') ||
          uuidStr.contains('fe00')) {
        return true;
      }
    }
    return false;
  }

  /// Convert standard image PNG/JPEG bytes into 1-bit monochrome raster rows for Niimbot B1
  static List<List<int>> imageToMonochromeRows(
    Uint8List imageBytes, {
    int targetWidth = maxPrintWidthDots,
    bool invertBits = false,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Could not decode image bytes for printing');
    }

    // Resize image maintaining aspect ratio to fit printhead width
    final scaled = img.copyResize(
      decoded,
      width: targetWidth,
      interpolation: img.Interpolation.linear,
    );

    final height = scaled.height;
    final bytesPerRow = (targetWidth / 8).ceil();
    final List<List<int>> rows = [];

    for (int y = 0; y < height; y++) {
      final List<int> rowBytes = List.filled(bytesPerRow, 0);
      for (int x = 0; x < targetWidth; x++) {
        if (x < scaled.width) {
          final pixel = scaled.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();
          final a = pixel.a.toDouble();

          // If transparent pixel, skip unless inverting
          if (a < 128) {
            if (invertBits) {
              final byteIndex = x ~/ 8;
              final bitIndex = 7 - (x % 8);
              rowBytes[byteIndex] |= (1 << bitIndex);
            }
            continue;
          }

          // Perceived brightness (0 = dark/black, 255 = light/white)
          final brightness = (r * 0.299 + g * 0.587 + b * 0.114);

          final isDark = brightness < 140;
          final setBit = invertBits ? !isDark : isDark;

          if (setBit) {
            final byteIndex = x ~/ 8;
            final bitIndex = 7 - (x % 8);
            rowBytes[byteIndex] |= (1 << bitIndex);
          }
        }
      }
      rows.add(rowBytes);
    }

    return rows;
  }

  static final List<BluetoothCharacteristic> _cachedWriteChars = [];

  /// Reassembles 0x55 0x55 ... 0xAA 0xAA frames out of raw BLE notify chunks
  /// (a single frame can be split across multiple notify events, or several
  /// frames can arrive concatenated in one event).
  static final List<int> _rxBuffer = [];
  static final StreamController<Map<String, dynamic>> _rxPacketController =
      StreamController<Map<String, dynamic>>.broadcast();

  static void _feedRxBytes(List<int> bytes) {
    _rxBuffer.addAll(bytes);

    while (true) {
      int headerIndex = -1;
      for (int i = 0; i <= _rxBuffer.length - 2; i++) {
        if (_rxBuffer[i] == 0x55 && _rxBuffer[i + 1] == 0x55) {
          headerIndex = i;
          break;
        }
      }
      if (headerIndex == -1) {
        if (_rxBuffer.length > 1) {
          _rxBuffer.removeRange(0, _rxBuffer.length - 1);
        }
        return;
      }
      if (headerIndex > 0) {
        _rxBuffer.removeRange(0, headerIndex);
      }

      if (_rxBuffer.length < 4) return;
      final cmd = _rxBuffer[2];
      final len = _rxBuffer[3];
      final totalPacketLen = 4 + len + 1 + 2; // header+cmd+len + payload + checksum + tail
      if (_rxBuffer.length < totalPacketLen) return;

      final payload = _rxBuffer.sublist(4, 4 + len);
      _rxPacketController.add({'cmd': cmd, 'payload': payload});
      _rxBuffer.removeRange(0, totalPacketLen);
    }
  }

  /// Sends a PrintStatus (0xA3) request and waits for a matching response.
  /// The printer replies with command 0xB3 (0xA3 itself just echoes back as a bare ack).
  static Future<Map<String, int>?> _requestPrintStatusOnce({
    Duration timeout = const Duration(milliseconds: 400),
  }) async {
    final completer = Completer<Map<String, int>?>();
    late final StreamSubscription sub;
    sub = _rxPacketController.stream.listen((pkt) {
      if (pkt['cmd'] == 0xB3) {
        final payload = pkt['payload'] as List<int>;
        if (payload.length >= 4 && !completer.isCompleted) {
          final page = (payload[0] << 8) | payload[1];
          int error = 0;
          if (payload.length >= 7) {
            error = payload[6];
          }
          completer.complete({
            'page': page,
            'pagePrintProgress': payload[2],
            'pageFeedProgress': payload[3],
            'error': error,
          });
        }
      }
    });

    await _sendBytesToAll(NiimbotPacketEncoder.cmdPrintStatus());
    final result = await completer.future.timeout(timeout, onTimeout: () => null);
    await sub.cancel();
    return result;
  }

  /// Polls PrintStatus until the printer reports 100% print + feed progress on the
  /// current page, or gives up after [maxAttempts]. Sending EndJob before this completes
  /// can make the printer discard whatever rows are still buffered and never fired the
  /// thermal head for. Progress hitting 100% is the direct "physically done" signal -
  /// faster and more reliable than waiting on the page counter, which can lag behind.
  static Future<bool> _waitForPrintFinished({int maxAttempts = 80}) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final status = await _requestPrintStatusOnce();
      if (status != null) {
        final error = status['error'] ?? 0;
        if (error != 0) {
          throw Exception('Printer reported error code $error while finishing print');
        }
        final printDone = (status['pagePrintProgress'] ?? 0) >= 100;
        final feedDone = (status['pageFeedProgress'] ?? 0) >= 100;
        if (printDone && feedDone) {
          return true;
        }
      }
      await Future.delayed(const Duration(milliseconds: 120));
    }
    return false;
  }

  /// Main method to print a label image on a NIIMBOT B1 BLE device
  static Future<NiimbotPrintResult> printLabel({
    required BluetoothDevice device,
    required Uint8List imageBytes,
    int quantity = 1,
    int density = 5,
    int labelType = 1,
    bool invertBits = false,
    void Function(double progress)? onProgress,
  }) async {
    try {
      debugPrint('[NiimbotPrinterService] === PRINT START === Device: ${device.platformName} (${device.remoteId.str}) | Density: $density | LabelType: $labelType | Invert: $invertBits');

      if (!device.isConnected || _cachedWriteChars.isEmpty) {
        debugPrint('[NiimbotPrinterService] Connecting to BLE device...');
        await device.connect(timeout: const Duration(seconds: 6));
        debugPrint('[NiimbotPrinterService] STEP 1: Connected');
        _rxBuffer.clear();

        try {
          await device.requestMtu(247);
          await Future.delayed(const Duration(milliseconds: 60));
        } catch (e) {
          debugPrint('[NiimbotPrinterService] requestMtu notice: $e');
        }

        final services = await device.discoverServices();
        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.properties.notify || c.properties.indicate) {
              try {
                await c.setNotifyValue(true);
                c.lastValueStream.listen((value) {
                  if (value.isNotEmpty) {
                    final hex = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
                    debugPrint('[NiimbotPrinterService] NOTIFY RESPONSE (${c.uuid}): [$hex]');
                    _feedRxBytes(value);
                  }
                });
              } catch (_) {}
            }
          }
        }

        _cachedWriteChars.clear();
        for (final s in services) {
          for (final c in s.characteristics) {
            if (c.properties.writeWithoutResponse || c.properties.write) {
              final uuid = c.uuid.toString().toLowerCase();
              if (uuid.contains('ffe1') || uuid.contains('fff2') || uuid.contains('bef8d6c9')) {
                _cachedWriteChars.add(c);
                debugPrint('[NiimbotPrinterService] Discovered Niimbot Print Char: $uuid');
              }
            }
          }
        }
      } else {
        debugPrint('[NiimbotPrinterService] Reusing active BLE connection across ${_cachedWriteChars.length} characteristics!');
      }

      if (_cachedWriteChars.isEmpty) {
        debugPrint('[NiimbotPrinterService] ERROR: No writable characteristic found');
        return NiimbotPrintResult(
          success: false,
          message: 'Хэвлэгчээс бичих боломжтой Bluetooth суваг олдсонгүй',
          deviceName: device.platformName,
        );
      }

      final rows = imageToMonochromeRows(imageBytes, invertBits: invertBits);
      final totalLines = rows.length;

      // Fast B1 Print Sequence sent to all writable characteristics:
      await _sendBytesToAll(NiimbotPacketEncoder.cmdConnect());
      await Future.delayed(const Duration(milliseconds: 30));

      await _sendBytesToAll(NiimbotPacketEncoder.cmdSetDensity(density: density));
      await Future.delayed(const Duration(milliseconds: 20));

      await _sendBytesToAll(NiimbotPacketEncoder.cmdSetLabelType(labelType: labelType));
      await Future.delayed(const Duration(milliseconds: 20));

      await _sendBytesToAll(NiimbotPacketEncoder.cmdStartJob(totalPages: quantity));
      await Future.delayed(const Duration(milliseconds: 30));

      for (int q = 0; q < quantity; q++) {
        await _sendBytesToAll(NiimbotPacketEncoder.cmdStartPage());
        await Future.delayed(const Duration(milliseconds: 20));

        await _sendBytesToAll(
          NiimbotPacketEncoder.cmdSetPageSize(
            rows: totalLines,
            cols: maxPrintWidthDots,
            copies: 1,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 20));

        // Ultra-Fast Batch Line Streaming (4 lines per BLE write)
        final List<int> lineBatchBuffer = [];
        for (int i = 0; i < totalLines; i++) {
          final linePacket = NiimbotPacketEncoder.cmdRasterLine(i, rows[i]);
          lineBatchBuffer.addAll(linePacket);

          if ((i + 1) % 4 == 0 || i == totalLines - 1) {
            await _sendBytesToAll(Uint8List.fromList(lineBatchBuffer));
            lineBatchBuffer.clear();

            if (onProgress != null && totalLines > 0) {
              onProgress(((q * totalLines + i + 1) / (quantity * totalLines)).clamp(0.0, 1.0));
            }
            await Future.delayed(const Duration(milliseconds: 12));
          }

          // Heartbeat every 24 lines
          if (i > 0 && i % 24 == 0) {
            await _sendBytesToAll(NiimbotPacketEncoder.cmdHeartbeat());
            await Future.delayed(const Duration(milliseconds: 15));
          }
        }

        await _sendBytesToAll(NiimbotPacketEncoder.cmdEndPage());
        await Future.delayed(const Duration(milliseconds: 20));
      }

      final finished = await _waitForPrintFinished();
      if (!finished) {
        debugPrint('[NiimbotPrinterService] WARNING: PrintStatus poll timed out waiting for printer to finish rendering - sending EndJob anyway');
      }

      await _sendBytesToAll(NiimbotPacketEncoder.cmdEndJob());
      debugPrint('[NiimbotPrinterService] === PRINT COMPLETE ===');

      return NiimbotPrintResult(
        success: true,
        message: 'Шошго амжилттай хэвлэгдлээ ($quantity хувь)',
        deviceName: device.platformName,
      );
    } catch (e, st) {
      debugPrint('[NiimbotPrinterService] BLE Print error: $e\n$st');
      _cachedWriteChars.clear();
      try {
        await device.disconnect();
      } catch (_) {}
      return NiimbotPrintResult(
        success: false,
        message: 'Хэвлэхэд алдаа гарлаа: $e',
        deviceName: device.platformName,
      );
    }
  }

  /// Send byte packet to all discovered writable characteristics
  static Future<void> _sendBytesToAll(Uint8List data) async {
    for (final char in _cachedWriteChars) {
      await _sendBytes(char, data);
    }
  }

  /// Helper to send bytes chunked by BLE MTU with write retry and pacing
  static Future<void> _sendBytes(
    BluetoothCharacteristic char,
    Uint8List data, {
    int chunkSize = 200,
  }) async {
    for (int i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
      final chunk = data.sublist(i, end);

      final allowWithoutResp = char.properties.writeWithoutResponse;
      try {
        await char.write(chunk, withoutResponse: allowWithoutResp);
      } catch (e) {
        try {
          await char.write(chunk, withoutResponse: !allowWithoutResp);
        } catch (_) {}
      }
    }
  }
}
