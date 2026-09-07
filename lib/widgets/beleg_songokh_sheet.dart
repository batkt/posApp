import 'package:flutter/material.dart';

import '../models/sales_model.dart';

/// Нэг урамшуулалд хэд хэдэн бэлэг тохируулсан үед сервер аль нь ч өгөхийг
/// шийдэхгүй — `songokhBelegnuud` буцааж, кассчингаас сонгуулна (вэб
/// `components/modalBody/posSystem/belegsongokh.js`).
///
/// Сонголт хийсний дараа [SalesModel.setSongogdsonBelegnuud] дуудагдаж,
/// сагсны гарын үсэг өөрчлөгдөн `POST /uramshuulalShalgay` дахин ажиллана.
Future<void> showBelegSongokhSheet(
  BuildContext context,
  SalesModel sales,
) async {
  final groups = sales.songokhBelegnuud;
  if (groups.isEmpty) return;
  final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _BelegSongokhSheet(
      groups: groups,
      initialSelected: sales.songogdsonBelegnuud,
    ),
  );
  if (result != null) {
    sales.setSongogdsonBelegnuud(result);
  }
}

String _giftKey(Map<String, dynamic> gift) {
  final promo = (gift['uramshuulaliinId'] ?? '').toString();
  final code = (gift['code'] ?? '').toString();
  return '$promo|$code';
}

class _BelegSongokhSheet extends StatefulWidget {
  const _BelegSongokhSheet({
    required this.groups,
    required this.initialSelected,
  });

  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> initialSelected;

  @override
  State<_BelegSongokhSheet> createState() => _BelegSongokhSheetState();
}

class _BelegSongokhSheetState extends State<_BelegSongokhSheet> {
  late final Map<String, Map<String, dynamic>> _selected = {
    for (final g in widget.initialSelected) _giftKey(g): g,
  };

  List<Map<String, dynamic>> _giftsOf(Map<String, dynamic> group) {
    final raw = group['belegnuud'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Урамшуулал сонгох',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final group in widget.groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                    child: Text(
                      group['ner']?.toString() ?? 'Урамшуулал',
                      style: textTheme.labelLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final gift in _giftsOf(group))
                    CheckboxListTile(
                      value: _selected.containsKey(_giftKey(gift)),
                      onChanged: (on) {
                        setState(() {
                          final k = _giftKey(gift);
                          if (on == true) {
                            _selected[k] = gift;
                          } else {
                            _selected.remove(k);
                          }
                        });
                      },
                      title: Text(gift['ner']?.toString() ?? '—'),
                      subtitle: Text(
                        'Код: ${gift['code'] ?? '—'} · '
                        'Тоо: ${gift['shirkheg'] ?? 0}',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Хаах'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _selected.values.toList()),
                    child: const Text('Хадгалах'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
