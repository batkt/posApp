import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/inventory_model.dart';
import '../models/locale_model.dart';
import '../models/sales_model.dart';
import '../utils/app_snackbar.dart';

String _formatPiecesField(double p) {
  if (p % 1 == 0) return p.toStringAsFixed(0);
  final s = p.toStringAsFixed(2);
  if (s.endsWith('0')) return s.substring(0, s.length - 1);
  return s;
}

double? _parsePiecesInput(String raw) {
  final t = raw.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Вэб [KhemjikhNegjUurchlukh]: `zadlakhToo` = нийт задлах **ширхэг**, дараа нь бөөний үнэ дахин.
Future<void> showBoxLinePiecesSheet(BuildContext context, SaleItem item) async {
  if (!item.product.isBoxSaleUnit) return;
  final neg = item.negPerBox;
  // Бутархай үлдэгдлийг (0.5 хайрцаг г.м.) тасалж болохгүй — яг утгаар.
  final rawMax = item.product.boditUldegdel * neg;
  final maxPieces = rawMax < 0.01 ? 0.01 : rawMax;
  final initial = item.effectivePieces.clamp(0.01, maxPieces);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
        ),
        child: _BoxLinePiecesEditor(
          item: item,
          neg: neg,
          maxPieces: maxPieces,
          initialPieces: initial,
        ),
      );
    },
  );
}

class _BoxLinePiecesEditor extends StatefulWidget {
  const _BoxLinePiecesEditor({
    required this.item,
    required this.neg,
    required this.maxPieces,
    required this.initialPieces,
  });

  final SaleItem item;
  final double neg;
  final double maxPieces;
  final double initialPieces;

  @override
  State<_BoxLinePiecesEditor> createState() => _BoxLinePiecesEditorState();
}

class _BoxLinePiecesEditorState extends State<_BoxLinePiecesEditor> {
  late final TextEditingController _text;
  final FocusNode _focus = FocusNode();

  /// Last known-good quantity for [+1]/[−1] when the field is mid-edit / empty.
  late double _anchor;

  double get _minPieces => widget.maxPieces < 1.0 ? 0.01 : 1.0;

  double get _currentPieces {
    final parsed = _parsePiecesInput(_text.text);
    if (parsed != null) {
      return parsed;
    }
    return _anchor;
  }

  bool get _canDecrement => _currentPieces > _minPieces;
  bool get _canIncrement => _currentPieces < widget.maxPieces;

  @override
  void initState() {
    super.initState();
    _anchor = widget.initialPieces.clamp(_minPieces, widget.maxPieces);
    _text = TextEditingController(text: _formatPiecesField(_anchor));
    _text.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _bump(double delta) {
    final parsed = _parsePiecesInput(_text.text);
    if (parsed != null) {
      _anchor = parsed.clamp(_minPieces, widget.maxPieces);
    }
    _anchor = (_anchor + delta).clamp(_minPieces, widget.maxPieces);
    final s = _formatPiecesField(_anchor);
    setState(() {
      _text.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    });
  }

  List<double> get _deltas {
    final set = <double>{1.0};
    final neg = widget.neg.roundToDouble();
    if (neg > 1) {
      if (neg == 5.0 || neg <= 4.0) {
        set.add(neg == 5.0 ? 5.0 : neg);
        if (neg < 5.0) set.add(5.0);
      } else if (neg == 10.0) {
        set.addAll([5.0, 10.0]);
      } else {
        set.addAll([5.0, neg]);
      }
    } else {
      set.add(5.0);
    }
    return set.toList()..sort();
  }

  Widget _deltaBtn(double delta, {required bool isMinus}) {
    final canPress = isMinus ? _canDecrement : _canIncrement;
    final label = isMinus ? '−${delta.abs().toInt()}' : '+${delta.toInt()}';
    return FilledButton.tonal(
      onPressed: canPress ? () => _bump(delta) : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDeltaRow() {
    final deltas = _deltas;
    final minusDeltas = deltas.reversed.toList();
    final plusDeltas = deltas;

    return Row(
      children: [
        for (final d in minusDeltas) ...[
          Expanded(child: _deltaBtn(-d, isMinus: true)),
          const SizedBox(width: 6),
        ],
        const SizedBox(width: 8),
        for (int i = 0; i < plusDeltas.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _deltaBtn(plusDeltas[i], isMinus: false)),
        ],
      ],
    );
  }

  void _submit(BuildContext ctx) {
    final l10n = AppLocalizations.of(ctx);
    final v = _parsePiecesInput(_text.text);
    if (v == null || v < _minPieces) {
      showAppSnackBar(ctx, l10n.tr('pos_sale_invalid_amount'),
          variant: AppSnackVariant.warning);
      return;
    }
    final pieces = v.clamp(_minPieces, widget.maxPieces);
    final sales = ctx.read<SalesModel>();
    final inv = ctx.read<InventoryModel>();
    sales.setBoxLinePieces(
      widget.item.product.id,
      pieces,
      inventory: inv,
    );
    Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tr('pos_sale_box_sheet_title'),
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                '${l10n.tr('pos_sale_box_sheet_per_box')}:',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${widget.neg.toInt()} ш',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                '${l10n.tr('pos_sale_box_sheet_stock_pieces')}:',
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${widget.maxPieces.toStringAsFixed(0)} ш',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: FilledButton.tonal(
                onPressed: _canDecrement ? () => _bump(-1) : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.remove_rounded, size: 28),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  hintText: l10n.tr('pos_sale_box_field_hint'),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 52,
              height: 52,
              child: FilledButton.tonal(
                onPressed: _canIncrement ? () => _bump(1) : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDeltaRow(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.tr('cancel')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () => _submit(context),
                child: Text(l10n.tr('save')),
              ),
            ),
          ],
        ),
        if (widget.item.boxPiecesSold != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              final sales = context.read<SalesModel>();
              sales.clearBoxLinePiecesOverride(widget.item.product.id);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.inventory_2_outlined, size: 16),
            label: const Text('Бүтэн хайрцгаар зарах'),
          ),
        ],
      ],
    );
  }
}
