import 'package:flutter/material.dart';

import '../services/socket_service.dart';
import '../services/terminal_barimt_signal_service.dart';

/// Button to trigger a remote E-Barimt / receipt print request to the POS thermal printer.
class PrintReceiptToPosButton extends StatefulWidget {
  const PrintReceiptToPosButton({
    super.key,
    required this.salbariinId,
    required this.barimtData,
    this.barimtType = 'ebarimt',
    this.tailbar = '',
    this.label = 'ПОС руу баримт хэвлэх',
    this.icon = Icons.print_rounded,
    this.onBeforeSend,
    this.onSuccess,
  });

  final String salbariinId;
  final Map<String, dynamic> barimtData;
  final String barimtType;
  final String tailbar;
  final String label;
  final IconData icon;
  final Future<Map<String, dynamic>?> Function()? onBeforeSend;
  final VoidCallback? onSuccess;

  @override
  State<PrintReceiptToPosButton> createState() => _PrintReceiptToPosButtonState();
}

class _PrintReceiptToPosButtonState extends State<PrintReceiptToPosButton> {
  bool _isLoading = false;
  final TerminalBarimtSignalService _svc = TerminalBarimtSignalService();

  Future<void> _sendPrintRequest() async {
    debugPrint('>>> [PrintReceiptToPosButton] BUTTON TAPPED! salbariinId: "${widget.salbariinId}"');
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> payload = widget.barimtData;
      if (widget.onBeforeSend != null) {
        final preparedData = await widget.onBeforeSend!();
        if (preparedData != null) {
          payload = preparedData;
        }
      }

      debugPrint('>>> [PrintReceiptToPosButton] Sending request payload: $payload');
      final createdItem = await _svc.createRequest(
        salbariinId: widget.salbariinId,
        barimtType: widget.barimtType,
        barimtData: payload,
        tailbar: widget.tailbar,
      );
      debugPrint('>>> [PrintReceiptToPosButton] SUCCESS! Request created on server.');

      if (createdItem != null) {
        SocketService.instance.notifyLocalPrintRequest({
          'id': createdItem.id,
          'barimtType': createdItem.barimtType,
          'barimtData': createdItem.barimtData,
          'initiatorNer': createdItem.initiatorNer,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ПОС терминал руу баримт хэвлэх хүсэлт амжилттай илгээгдлээ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      widget.onSuccess?.call();
    } catch (e, st) {
      debugPrint('[PrintReceiptToPosButton] Error sending print request: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _sendPrintRequest,
      icon: _isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(widget.icon, size: 20),
      label: Text(widget.label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
