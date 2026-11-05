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
    final tt = Theme.of(context).textTheme;
    final n = _nekhemjlekh;
    final String? qrText =
        (n != null && n['turul'] == 'qr') ? n['qrText']?.toString() : null;
    final utasIlgeesen = n != null && n['turul'] == 'utas';
    final khuleejBaigaa =
        _orderId != null && (_utasaar ? utasIlgeesen : qrText != null);

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Толгой: лого + төлөх дүн (системийн өнгө, dark mode дагана)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 18),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset('assets/images/toki_logo.png',
                              width: 28, height: 28),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Toki-гоор төлөх',
                              style: tt.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          onPressed: _khaay,
                          tooltip: 'Хаах',
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      MntAmountFormatter.formatTugrik(widget.amountMnt),
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Захиалга #${widget.guilgeeniiDugaar}',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: false,
                            icon: Icon(Icons.qr_code_2_rounded),
                            label: Text('QR код')),
                        ButtonSegment(
                            value: true,
                            icon: Icon(Icons.phone_iphone_rounded),
                            label: Text('Утасны дугаар')),
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
                    const SizedBox(height: 18),
                    if (!_utasaar) ...[
                      Center(
                        child: Container(
                          width: 232,
                          height: 232,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            // QR-ыг уншихад цагаан дэвсгэр хэрэгтэй (dark mode-д ч).
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: qrText != null && qrText.isNotEmpty
                              ? QrImageView(
                                  data: qrText,
                                  size: 208,
                                  eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF101318)),
                                  dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF101318)),
                                )
                              : _loading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : Center(
                                      child: TextButton.icon(
                                        onPressed: () => _uusgey(),
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Дахин үүсгэх'),
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Хэрэглэгч Toki апп-аараа уншуулж төлнө.',
                        textAlign: TextAlign.center,
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ] else ...[
                      TextField(
                        controller: _utas,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        maxLength: 8,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: tt.titleLarge?.copyWith(letterSpacing: 1.2),
                        decoration: InputDecoration(
                          prefixText: '+976  ',
                          hintText: 'Утасны дугаар',
                          counterText: '',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (_utas.text.length == 8 && !_loading) {
                            _uusgey(utas: _utas.text);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      if (utasIlgeesen)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_rounded,
                                  size: 18, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_utas.text} дугаарт хүсэлт очсон. Хэрэглэгч Toki апп-аас баталгаажуулна.',
                                  style: tt.bodySmall,
                                ),
                              ),
                              TextButton(
                                onPressed: _loading || _utas.text.length != 8
                                    ? null
                                    : () => _uusgey(utas: _utas.text),
                                child: const Text('Дахин'),
                              ),
                            ],
                          ),
                        )
                      else
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: cs.onSurface,
                            foregroundColor: cs.surface,
                          ),
                          onPressed: _loading || _utas.text.length != 8
                              ? null
                              : () => _uusgey(utas: _utas.text),
                          child: _loading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: cs.surface))
                              : const Text('Хүсэлт илгээх'),
                        ),
                    ],
                    if (khuleejBaigaa) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFFE6C200),
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text('Төлбөр хүлээж байна',
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48)),
                          onPressed: _khaay,
                          child: const Text('Болих'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: cs.onSurface,
                              foregroundColor: cs.surface,
                            ),
                            onPressed: _orderId == null || _checking
                                ? null
                                : () => _shalgay(true),
                            child: _checking
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: cs.surface))
                                : const Text('Төлөлт шалгах'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
