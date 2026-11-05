import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/pos_transaction_service.dart';
import '../services/toki_service.dart';
import '../utils/app_snackbar.dart';
import '../utils/mnt_amount_formatter.dart';

/// TokiPay: QR уншуулах эсвэл утасны дугаар руу хүсэлт илгээнэ.
/// Төлөгдвөл `orderId`-г буцаана (гүйлгээний `tulbur[].tokiOrderId`), болих бол null.
/// Төлөгдөөгүй хаавал нэхэмжлэхийг цуцална.
class TokiInvoiceDialog extends StatefulWidget {
  const TokiInvoiceDialog({
    super.key,
    required this.amountMnt,
    required this.baiguullagiinId,
    required this.salbariinId,
    required this.guilgeeniiDugaar,
  });

  final double amountMnt;
  final String baiguullagiinId;
  final String salbariinId;
  final String guilgeeniiDugaar;

  @override
  State<TokiInvoiceDialog> createState() => _TokiInvoiceDialogState();
}

class _TokiInvoiceDialogState extends State<TokiInvoiceDialog> {
  final _svc = TokiService();
  final _utas = TextEditingController();
  Timer? _poll;
  bool _utasaar = false;
  bool _loading = false;
  bool _checking = false;
  bool _duussan = false;
  Map<String, dynamic>? _nekhemjlekh;

  String? get _orderId => _nekhemjlekh?['orderId']?.toString();

  @override
  void initState() {
    super.initState();
    _uusgey();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _shalgay(false));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _utas.dispose();
    super.dispose();
  }

  Future<void> _uusgey({String? utas}) async {
    final umnukh = _orderId;
    setState(() => _loading = true);
    try {
      final r = utas != null
          ? await _svc.utasaarGargaya(
              dun: widget.amountMnt,
              baiguullagiinId: widget.baiguullagiinId,
              salbariinId: widget.salbariinId,
              guilgeeniiDugaar: widget.guilgeeniiDugaar,
              utas: utas,
            )
          : await _svc.qrGargaya(
              dun: widget.amountMnt,
              baiguullagiinId: widget.baiguullagiinId,
              salbariinId: widget.salbariinId,
              guilgeeniiDugaar: widget.guilgeeniiDugaar,
            );
      if (!mounted) return;
      setState(() => _nekhemjlekh = r);
      if (umnukh != null) _svc.tsutslakh(umnukh);
      if (utas != null) {
        showAppSnackBar(context, 'Toki апп руу төлбөрийн хүсэлт илгээлээ');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, posPaymentErrorUserMessage(e),
            variant: AppSnackVariant.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shalgay(bool garaar) async {
    final id = _orderId;
    if (id == null || _checking || _duussan) return;
    _checking = true;
    if (garaar) setState(() {});
    try {
      final r = await _svc.shalgakh(id);
      if (!mounted) return;
      if (r['tulsunEsekh'] == true) {
        _duussan = true;
        Navigator.of(context).pop(id);
      } else if (garaar) {
        final tuluv = r['tuluv']?.toString();
        showAppSnackBar(
          context,
          tuluv == 'EXPIRED'
              ? 'Нэхэмжлэхийн хугацаа дууссан. Дахин үүсгэнэ үү.'
              : tuluv == 'CANCELLED'
                  ? 'Нэхэмжлэх цуцлагдсан байна.'
                  : 'Toki төлбөр төлөгдөөгүй байна.',
          variant: AppSnackVariant.warning,
        );
      }
    } catch (e) {
      if (garaar && mounted) {
        showAppSnackBar(context, posPaymentErrorUserMessage(e),
            variant: AppSnackVariant.error);
      }
    } finally {
      _checking = false;
      if (garaar && mounted) setState(() {});
    }
  }

  void _khaay() {
    final id = _orderId;
    if (id != null && !_duussan) _svc.tsutslakh(id);
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = _nekhemjlekh;
    final String? qrText = (n != null && n['turul'] == 'qr') ? n['qrText']?.toString() : null;

    return AlertDialog(
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/images/toki_logo.png', width: 28, height: 28),
          ),
          const SizedBox(width: 10),
          const Text('TokiPay'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('QR')),
                ButtonSegment(value: true, label: Text('Утсаар')),
              ],
              selected: {_utasaar},
              onSelectionChanged: _loading
                  ? null
                  : (v) {
                      final shine = v.first;
                      if (shine == _utasaar) return;
                      setState(() => _utasaar = shine);
                      if (!shine) _uusgey();
                    },
            ),
            const SizedBox(height: 16),
            if (!_utasaar)
              SizedBox(
                width: 220,
                height: 220,
                child: qrText != null && qrText.isNotEmpty
                    ? Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: QrImageView(data: qrText, size: 204),
                      )
                    : Center(
                        child: _loading
                            ? const CircularProgressIndicator()
                            : Icon(Icons.qr_code_2_rounded,
                                size: 80, color: cs.outline),
                      ),
              )
            else
              Column(
                children: [
                  TextField(
                    controller: _utas,
                    keyboardType: TextInputType.phone,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Хэрэглэгчийн утасны дугаар',
                      hintText: '99112233',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  FilledButton.tonal(
                    onPressed: _loading || _utas.text.length != 8
                        ? null
                        : () => _uusgey(utas: _utas.text),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Хүсэлт илгээх'),
                  ),
                  if (_nekhemjlekh?['turul'] == 'utas')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Хүсэлт илгээгдсэн. Хэрэглэгч Toki апп-аас батална.',
                        style: TextStyle(color: cs.primary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Text(
              MntAmountFormatter.formatTugrik(widget.amountMnt),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _khaay, child: const Text('Болих')),
        FilledButton(
          onPressed: _orderId == null || _checking ? null : () => _shalgay(true),
          child: const Text('Шалгах'),
        ),
      ],
    );
  }
}
