import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/niimbot_printer_service.dart';
import '../utils/app_snackbar.dart';
import '../utils/niimbot_label_builder.dart';

class NiimbotPrinterDialog extends StatefulWidget {
  final String productName;
  final String priceText;
  final String? barcodeOrSku;
  final String storeName;

  const NiimbotPrinterDialog({
    super.key,
    required this.productName,
    required this.priceText,
    this.barcodeOrSku,
    this.storeName = 'POSEASE',
  });

  static Future<void> show(
    BuildContext context, {
    required String productName,
    required String priceText,
    String? barcodeOrSku,
    String storeName = 'POSEASE',
  }) {
    return showDialog(
      context: context,
      builder: (context) => NiimbotPrinterDialog(
        productName: productName,
        priceText: priceText,
        barcodeOrSku: barcodeOrSku,
        storeName: storeName,
      ),
    );
  }

  @override
  State<NiimbotPrinterDialog> createState() => _NiimbotPrinterDialogState();
}

class _NiimbotPrinterDialogState extends State<NiimbotPrinterDialog> {
  Uint8List? _labelImageBytes;
  bool _isGeneratingPreview = true;
  bool _isPrinting = false;
  double _printProgress = 0.0;
  int _quantity = 1;
  String? _statusMessage;

  final int _density = 5;
  final int _labelType = 1;
  final bool _invertBits = false;

  BluetoothDevice? _selectedDevice;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    _buildLabelPreview();
    _startBluetoothScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    NiimbotPrinterService.stopScan();
    super.dispose();
  }

  Future<void> _buildLabelPreview() async {
    setState(() => _isGeneratingPreview = true);
    try {
      final bytes = await NiimbotLabelBuilder.generateProductLabelImage(
        title: widget.productName,
        priceText: widget.priceText,
        barcodeOrSku: widget.barcodeOrSku,
        storeName: widget.storeName,
      );
      if (mounted) {
        setState(() {
          _labelImageBytes = bytes;
          _isGeneratingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Урьдчилан харах зураг үүсгэхэд алдаа гарлаа: $e';
          _isGeneratingPreview = false;
        });
      }
    }
  }

  Future<void> _startBluetoothScan() async {
    setState(() {
      _scanResults.clear();
    });

    // Fetch already connected BLE devices so they never disappear from the list
    final systemConnected = FlutterBluePlus.connectedDevices;
    final List<ScanResult> connectedResults = [];
    for (final dev in systemConnected) {
      final dummyAdv = AdvertisementData(
        advName: dev.platformName,
        txPowerLevel: null,
        connectable: true,
        manufacturerData: {},
        serviceData: {},
        serviceUuids: [],
        appearance: null,
      );
      connectedResults.add(ScanResult(
        device: dev,
        advertisementData: dummyAdv,
        rssi: 0,
        timeStamp: DateTime.now(),
      ));
      if (_selectedDevice == null && NiimbotPrinterService.isNiimbotDevice(dev.platformName)) {
        _selectedDevice = dev;
      }
    }

    // Show already-connected devices immediately - don't wait on a scan event that may
    // never fire (a connected peripheral usually stops advertising, so it won't show up
    // in the live scan stream on its own).
    if (mounted) {
      setState(() => _scanResults = connectedResults);
    }

    if (_selectedDevice != null) {
      // A printer is already connected/chosen - no need to keep scanning.
      NiimbotPrinterService.stopScan();
      return;
    }

    _scanSub?.cancel();
    _scanSub = NiimbotPrinterService.scanForPrinters().listen((results) {
      if (mounted) {
        final Map<String, ScanResult> map = {};
        for (final c in connectedResults) {
          map[c.device.remoteId.str] = c;
        }
        for (final r in results) {
          map[r.device.remoteId.str] = r;
        }

        final sorted = map.values.toList()
          ..sort((a, b) {
            final aConn = a.device.isConnected;
            final bConn = b.device.isConnected;
            if (aConn && !bConn) return -1;
            if (!aConn && bConn) return 1;

            final aIsNiimbot = NiimbotPrinterService.isNiimbotScanResult(a);
            final bIsNiimbot = NiimbotPrinterService.isNiimbotScanResult(b);
            if (aIsNiimbot && !bIsNiimbot) return -1;
            if (!aIsNiimbot && bIsNiimbot) return 1;

            final aName = NiimbotPrinterService.getDeviceDisplayName(a);
            final bName = NiimbotPrinterService.getDeviceDisplayName(b);
            if (aName.isNotEmpty && bName.isEmpty) return -1;
            if (aName.isEmpty && bName.isNotEmpty) return 1;

            return aName.compareTo(bName);
          });

        setState(() {
          _scanResults = sorted;
          if (_selectedDevice == null) {
            for (final r in sorted) {
              if (NiimbotPrinterService.isNiimbotScanResult(r)) {
                _selectedDevice = r.device;
                break;
              }
            }
          }
        });

        if (_selectedDevice != null) {
          // Found a printer to use - no need to keep scanning.
          _scanSub?.cancel();
          NiimbotPrinterService.stopScan();
        }
      }
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Bluetooth хайлтын алдаа: $e';
        });
      }
    });
  }

  Future<void> _onPrintPressed() async {
    if (_selectedDevice == null) {
      showAppSnackBar(context, 'Эхлээд Niimbot хэвлэгч сонгоно уу',
          variant: AppSnackVariant.warning);
      return;
    }
    if (_labelImageBytes == null) return;

    setState(() {
      _isPrinting = true;
      _printProgress = 0.0;
      _statusMessage = 'Холбогдож, хэвлэж байна...';
    });

    final res = await NiimbotPrinterService.printLabel(
      device: _selectedDevice!,
      imageBytes: _labelImageBytes!,
      quantity: _quantity,
      density: _density,
      labelType: _labelType,
      invertBits: _invertBits,
      onProgress: (p) {
        if (mounted) setState(() => _printProgress = p);
      },
    );

    if (mounted) {
      setState(() {
        _isPrinting = false;
        _statusMessage = res.message;
      });

      showAppSnackBar(
        context,
        res.message,
        variant: res.success ? AppSnackVariant.success : AppSnackVariant.error,
      );
    }
  }

  void _showLogsModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        final logs = NiimbotPrinterService.getSessionLogs();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.terminal, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Хэвлэгчийн Лог (Logs)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  logs,
                  style: const TextStyle(fontSize: 11, color: Colors.greenAccent, fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                NiimbotPrinterService.clearSessionLogs();
                Navigator.of(ctx).pop();
                _showLogsModal();
              },
              child: const Text('Цэвэрлэх', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: logs));
                Navigator.of(ctx).pop();
                showAppSnackBar(
                  context,
                  'Хэвлэгчийн лог санамжид амжилттай хуулагдлаа!',
                  variant: AppSnackVariant.success,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Лог хуулах (Copy)'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.print, color: Colors.blueAccent),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'NIIMBOT B1 Шошго Хэвлэх',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, color: Colors.indigo),
            tooltip: 'Лог харах/хуулах',
            onPressed: _showLogsModal,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label Preview Section
            const Text(
              'Шошгоны загвар (40x30мм):',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _isGeneratingPreview
                  ? const Center(child: CircularProgressIndicator())
                  : (_labelImageBytes != null
                      ? Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.memory(
                            _labelImageBytes!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : const Center(child: Text('Урьдчилан харах зургийг үүсгэж чадсангүй'))),
            ),
            const SizedBox(height: 16),

            // Quantity selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Тоо ширхэг:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _quantity < 99
                          ? () => setState(() => _quantity++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),

            // Bluetooth Scanner & Device Picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Хэвлэгч сонгох:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    if (_selectedDevice != null && _selectedDevice!.isConnected) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                        onPressed: () async {
                          try {
                            await _selectedDevice!.disconnect();
                            if (mounted) {
                              setState(() {
                                _statusMessage = '${_selectedDevice!.platformName}-с салгагдлаа';
                              });
                            }
                            _startBluetoothScan();
                          } catch (e) {
                            debugPrint('Disconnect error: $e');
                          }
                        },
                        icon: const Icon(Icons.bluetooth_disabled, size: 16),
                        label: const Text('Салгах', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),

            Builder(
              builder: (context) {
                final Map<String, ScanResult> uniqueScanMap = {};
                for (final res in _scanResults) {
                  uniqueScanMap[res.device.remoteId.str] = res;
                }
                final uniqueScanList = uniqueScanMap.values.toList();

                BluetoothDevice? currentValue;
                if (_selectedDevice != null) {
                  for (final res in uniqueScanList) {
                    if (res.device.remoteId.str == _selectedDevice!.remoteId.str) {
                      currentValue = res.device;
                      break;
                    }
                  }
                }

                return DropdownButtonFormField<BluetoothDevice>(
                  initialValue: currentValue,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  hint: const Text('Bluetooth хэвлэгч сонгоно уу'),
                  isExpanded: true,
                  items: uniqueScanList.map((res) {
                    final displayName = NiimbotPrinterService.getDeviceDisplayName(res);
                    final isNiimbot = NiimbotPrinterService.isNiimbotScanResult(res);

                    return DropdownMenuItem<BluetoothDevice>(
                      value: res.device,
                      child: Row(
                        children: [
                          Icon(
                            isNiimbot ? Icons.print_rounded : Icons.bluetooth_rounded,
                            color: isNiimbot ? Colors.blueAccent : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayName.isNotEmpty ? displayName : 'Bluetooth төхөөрөмж',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isNiimbot ? FontWeight.bold : FontWeight.w500,
                                color: displayName.isNotEmpty
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (res.device.isConnected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: const Text(
                                'ХОЛБОГДСОН',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ] else if (isNiimbot) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: const Text(
                                'NIIMBOT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (device) {
                    setState(() => _selectedDevice = device);
                  },
                );
              },
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusMessage!.contains('алдаа')
                      ? Colors.red
                      : Colors.blue,
                  fontSize: 12,
                ),
              ),
            ],

            if (_isPrinting) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _printProgress),
              const SizedBox(height: 4),
              Text(
                'Хэвлэж байна: ${(_printProgress * 100).toInt()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
          child: const Text('Цуцлах'),
        ),
        ElevatedButton.icon(
          onPressed: _isPrinting || _selectedDevice == null ? null : _onPrintPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.print),
          label: const Text('Шошго хэвлэх'),
        ),
      ],
    );
  }
}
