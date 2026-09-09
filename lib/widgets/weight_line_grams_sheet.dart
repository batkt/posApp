import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/inventory_model.dart';
import '../models/locale_model.dart';
import '../models/sales_model.dart';
import '../utils/app_snackbar.dart';
import '../utils/mnt_amount_formatter.dart';

double? _parseGramsInput(String raw) {
  final t = raw.trim().replaceAll(',', '.').replaceAll(' ', '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String _formatGramsField(double g) =>
    g % 1 == 0 ? g.toStringAsFixed(0) : g.toStringAsFixed(1);

/// Жингийн (кг/гр) барааг ГРАММААР зарах цонх.
///
/// [showBoxLinePiecesSheet]-ийн ихрийн ах: тэр нь хайрцгийг ширхэгээр задалдаг
/// бол энэ нь килограммыг граммаар задалдаг.
Future<void> showWeightLineGramsSheet(
  BuildContext context,
  SaleItem item,
) async {
  if (!item.product.isWeightSaleUnit) return;
  final maxKg = (item.product.uldegdel ?? item.product.stock).toDouble();
  if (maxKg <= 0) return;

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
        child: _WeightGramsEditor(
          item: item,
          maxGrams: maxKg * 1000,
          initialGrams: (item.effectivePieces * 1000).clamp(1, maxKg * 1000),
        ),
      );
    },
  );
}

class _WeightGramsEditor extends StatefulWidget {
  const _WeightGramsEditor({
    required this.item,
    required this.maxGrams,
    required this.initialGrams,
  });

  final SaleItem item;
  final double maxGrams;
  final double initialGrams;

  @override
  State<_WeightGramsEditor> createState() => _WeightGramsEditorState();
}

class _WeightGramsEditorState extends State<_WeightGramsEditor> {
  late final TextEditingController _text;

  /// Талбар засагдаж байх үеийн сүүлийн зөв утга (түргэн товчид хэрэгтэй).
  late double _anchor;

  @override
  void initState() {
    super.initState();
    _anchor = widget.initialGrams.clamp(1, widget.maxGrams);
    _text = TextEditingController(text: _formatGramsField(_anchor));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  double get _currentGrams {
    final v = _parseGramsInput(_text.text);
    if (v == null || v <= 0) return _anchor;
    return v.clamp(1, widget.maxGrams);
  }

  void _setGrams(double g) {
    final clamped = g.clamp(1, widget.maxGrams).toDouble();
    _anchor = clamped;
    final s = _formatGramsField(clamped);
    setState(() {
      _text.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    });
  }

  void _submit(BuildContext ctx) {
    final l10n = AppLocalizations.of(ctx);
    final v = _parseGramsInput(_text.text);
    if (v == null || v <= 0) {
      showAppSnackBar(ctx, l10n.tr('pos_sale_invalid_amount'),
          variant: AppSnackVariant.warning);
      return;
    }
    ctx.read<SalesModel>().setWeightLineGrams(
          widget.item.product.id,
          v.clamp(1, widget.maxGrams).toDouble(),
          inventory: ctx.read<InventoryModel>(),
        );
    Navigator.pop(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final grams = _currentGrams;
    final lineTotal = widget.item.unitPrice * (grams / 1000);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.tr('pos_sale_weight_sheet_title'),
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.item.product.name,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        _row(tt, l10n.tr('pos_sale_weight_stock'),
            '${(widget.maxGrams / 1000).toStringAsFixed(2)} кг'),
        const SizedBox(height: 8),
        _row(
          tt,
          l10n.tr('pos_sale_weight_total'),
          '${(grams / 1000).toStringAsFixed(3)} кг · '
              '${MntAmountFormatter.formatTugrik(lineTotal)}',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _text,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: false,
          ),
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(context),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            hintText: l10n.tr('pos_sale_weight_field_hint'),
            suffixText: 'гр',
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
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in [100.0, 250.0, 500.0, 1000.0])
              FilledButton.tonal(
                onPressed: () => _setGrams(g),
                child: Text(g >= 1000 ? '1 кг' : '${g.toInt()} гр'),
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

  Widget _row(TextTheme tt, String label, String value) => Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
}
