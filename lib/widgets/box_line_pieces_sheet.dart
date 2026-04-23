import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/inventory_model.dart';
import '../models/locale_model.dart';
import '../models/sales_model.dart';

String _formatPiecesField(double p) =>
    p % 1 == 0 ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

double? _parsePiecesInput(String raw) {
  final t = raw.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Вэб [KhemjikhNegjUurchlukh]: `zadlakhToo` = нийт задлах **ширхэг**, дараа нь бөөний үнэ дахин.
Future<void> showBoxLinePiecesSheet(BuildContext context, SaleItem item) async {
  if (!item.product.isBoxSaleUnit) return;
  final neg = item.negPerBox;
  final maxPieces =
      (item.product.uldegdel ?? item.product.stock).toDouble() * neg;
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

  @override
  void initState() {
    super.initState();
    _anchor = widget.initialPieces.clamp(0.01, widget.maxPieces);
    _text = TextEditingController(text: _formatPiecesField(_anchor));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _bump(double delta) {
    final parsed = _parsePiecesInput(_text.text);
    if (parsed != null) {
      _anchor = parsed.clamp(0.01, widget.maxPieces);
    }
    _anchor = (_anchor + delta).clamp(0.01, widget.maxPieces);
    final s = _formatPiecesField(_anchor);
    setState(() {
      _text.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    });
  }

  void _submit(BuildContext ctx) {
    final l10n = AppLocalizations.of(ctx);
    final v = _parsePiecesInput(_text.text);
    if (v == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(l10n.tr('pos_sale_invalid_amount')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final pieces = v.clamp(0.01, widget.maxPieces);
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
        TextField(
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
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in [1.0, 5.0])
              FilledButton.tonal(
                onPressed: () => _bump(d),
                child: Text('+${d.toInt()}'),
              ),
            FilledButton.tonal(
              onPressed: () => _bump(-1),
              child: const Text('−1'),
            ),
          ],
        ),
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
      ],
    );
  }
}
