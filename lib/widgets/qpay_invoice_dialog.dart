import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/qpay_service.dart';

/// Same flow as web [QpayModal]: QR + **Шалгах** + background polling.
class QpayInvoiceDialog extends StatefulWidget {
  const QpayInvoiceDialog({
    super.key,
    required this.khariu,
    required this.amountMnt,
    required this.baiguullagiinId,
    required this.salbariinId,
    required this.zakhialgiinDugaar,
  });

  final Map<String, dynamic> khariu;
  final double amountMnt;
  final String baiguullagiinId;
  final String salbariinId;
  final String zakhialgiinDugaar;

  @override
  State<QpayInvoiceDialog> createState() => _QpayInvoiceDialogState();
}

class _QpayInvoiceDialogState extends State<QpayInvoiceDialog> {
  Timer? _poll;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _pollOnce());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pollOnce() async {
    if (!mounted || _checking) return;
    _checking = true;
    try {
      final ok = await QpayService().shalgakh(
        baiguullagiinId: widget.baiguullagiinId,
        salbariinId: widget.salbariinId,
        zakhialgiinDugaar: widget.zakhialgiinDugaar,
      );
      if (ok && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      // ignore transient errors while polling
    } finally {
      _checking = false;
    }
  }

  Future<void> _onShalgakh() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final ok = await QpayService().shalgakh(
        baiguullagiinId: widget.baiguullagiinId,
        salbariinId: widget.salbariinId,
        zakhialgiinDugaar: widget.zakhialgiinDugaar,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QPay төлөгдөөгүй байна.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b64 = widget.khariu['qr_image']?.toString();
    Uint8List? bytes;
    if (b64 != null && b64.isNotEmpty) {
      try {
        bytes = base64Decode(b64);
      } catch (_) {}
    }

    return AlertDialog(
      title: const Text('QPay'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  bytes,
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.error_outline),
                ),
              )
            else
              Icon(Icons.qr_code_2_rounded, size: 80, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              '${widget.amountMnt.round()}₮',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('Болих'),
        ),
        FilledButton(
          onPressed: _checking ? null : _onShalgakh,
          child: _checking
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Шалгах'),
        ),
      ],
    );
  }
}
