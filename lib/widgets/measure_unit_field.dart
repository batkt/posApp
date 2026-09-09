import 'package:flutter/material.dart';

/// Хэмжих нэгжийн сонголтуудыг бүрдүүлэх, шүүх туслах.
abstract final class MeasureUnitOptions {
  /// Монголд түгээмэл хэрэглэгддэг нэгжүүд.
  static const List<String> standard = <String>[
    'ш',
    'кг',
    'гр',
    'л',
    'мл',
    'м',
    'см',
    'хайрцаг',
    'багц',
    'ширхэг',
    'тонн',
    'хос',
  ];

  /// [standard] дээр агуулахад аль хэдийн ХЭРЭГЛЭГДСЭН нэгжүүдийг нэмнэ.
  ///
  /// Ингэснээр байгууллага өөрийн онцлог нэгжээ (жишээ нь "баглаа") нэг удаа
  /// бичихэд дараагийн бараанд нь жагсаалтаас сонгогдоно.
  static List<String> build(Iterable<String> existing) {
    final seen = <String>{};
    final out = <String>[];
    for (final u in [...standard, ...existing]) {
      final t = u.trim();
      if (t.isEmpty) continue;
      if (seen.add(t.toLowerCase())) out.add(t);
    }
    return out;
  }

  /// Бичсэн текстээр шүүнэ (том/жижиг үсэг ялгахгүй).
  static List<String> filter(List<String> options, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return options;
    return options.where((o) => o.toLowerCase().contains(q)).toList();
  }
}

/// Хэмжих нэгж оруулах талбар — ХАЙЖ сонгох ба гараас бичих аль аль нь.
///
/// Өмнө нь энгийн текст талбар байсан тул нэг байгууллага дотор "ш", "шир",
/// "ширхэг" гэх мэт зөрүүтэй бичиглэл үүсэж, хайрцаг/жингийн логик (
/// `Product.isBoxSaleUnit`, `isWeightSaleUnit`) нь нэгжийн бичиглэлээс
/// хамаардаг тул буруу ажиллах эрсдэлтэй байв.
class MeasureUnitField extends StatefulWidget {
  const MeasureUnitField({
    super.key,
    required this.controller,
    required this.label,
    this.existingUnits = const <String>[],
  });

  final TextEditingController controller;
  final String label;
  final Iterable<String> existingUnits;

  @override
  State<MeasureUnitField> createState() => _MeasureUnitFieldState();
}

class _MeasureUnitFieldState extends State<MeasureUnitField> {
  // [RawAutocomplete] нь ижил FocusNode-той байхыг шаарддаг — build бүрд
  // шинээр үүсгэвэл фокус алдагдаж, node нь ч цэвэрлэгдэхгүй.
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final options = MeasureUnitOptions.build(widget.existingUnits);

    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: _focus,
      optionsBuilder: (value) =>
          MeasureUnitOptions.filter(options, value.text),
      onSelected: (v) => controller.text = v,
      fieldViewBuilder: (context, textController, focusNode, onSubmit) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          onTapOutside: (_) => focusNode.unfocus(),
          onFieldSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
            helperText: 'Жагсаалтаас сонгох эсвэл шинээр бичнэ үү',
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, opts) {
        final list = opts.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  dense: true,
                  title: Text(list[i]),
                  onTap: () => onSelected(list[i]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
