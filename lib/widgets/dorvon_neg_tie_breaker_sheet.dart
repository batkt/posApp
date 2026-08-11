import 'package:flutter/material.dart';

import '../models/sales_model.dart';
import '../utils/dorvon_neg_uramshuulal.dart';
import '../utils/mnt_amount_formatter.dart';

/// "N-т 1 үнэгүй" урамшуулалд чөлөөлөгдөх сүүлийн нэгж(үүд)ийн үнэ өөр өөр 2+
/// баранд тэнцүү орсон (тэнцвэртэй) үед аль барааг нь үнэгүй болгохыг
/// кассчингаас сонгуулна. Сонголт хийхгүй бол систем автоматаар сонгоно.
Future<void> showDorvonNegTieBreakerSheet(
  BuildContext context,
  SalesModel sales,
) async {
  final calc = sales.dorvonNegCalc;
  if (!calc.hasTie) return;
  final result = await showModalBottomSheet<Map<String, int>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _DorvonNegTieBreakerSheet(
      candidates: calc.tieCandidates,
      slotsNeeded: calc.tieSlotsNeeded,
      initialPicks: sales.dorvonNegManualPicks,
    ),
  );
  if (result != null) {
    sales.setDorvonNegManualPicks(result);
  }
}

class _DorvonNegTieBreakerSheet extends StatefulWidget {
  const _DorvonNegTieBreakerSheet({
    required this.candidates,
    required this.slotsNeeded,
    required this.initialPicks,
  });

  final List<DorvonNegTieCandidate> candidates;
  final int slotsNeeded;
  final Map<String, int> initialPicks;

  @override
  State<_DorvonNegTieBreakerSheet> createState() =>
      _DorvonNegTieBreakerSheetState();
}

class _DorvonNegTieBreakerSheetState
    extends State<_DorvonNegTieBreakerSheet> {
  late Map<String, int> _picks;

  @override
  void initState() {
    super.initState();
    _picks = Map.of(widget.initialPicks);
  }

  int _pickedFor(DorvonNegTieCandidate c) {
    final raw = _picks[c.id] ?? 0;
    return raw.clamp(0, c.availableUnits);
  }

  int get _chosenTotal =>
      widget.candidates.fold(0, (s, c) => s + _pickedFor(c));

  void _bump(DorvonNegTieCandidate c, int delta) {
    setState(() {
      final v = (_pickedFor(c) + delta).clamp(0, c.availableUnits);
      if (v == 0) {
        _picks.remove(c.id);
      } else {
        _picks[c.id] = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canSave = _chosenTotal == widget.slotsNeeded;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Text(
                  'Аль барааг үнэгүй болгох вэ?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'Эдгээр бараа ижил үнэтэй тул ${widget.slotsNeeded} ширхэгийг алинаас нь үнэгүй болгохыг та сонгоно уу.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
              for (final c in widget.candidates)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${MntAmountFormatter.formatTugrik(c.price)} · сагсанд ${c.availableUnits} ш',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TieStepper(
                          value: _pickedFor(c),
                          onDecrement: () => _bump(c, -1),
                          onIncrement: (_pickedFor(c) < c.availableUnits &&
                                  _chosenTotal < widget.slotsNeeded)
                              ? () => _bump(c, 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: canSave
                        ? () => Navigator.pop(context, Map.of(_picks))
                        : null,
                    child: Text(
                      'Хадгалах ($_chosenTotal/${widget.slotsNeeded})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TieStepper extends StatelessWidget {
  const _TieStepper({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            onPressed: value <= 0 ? null : onDecrement,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
