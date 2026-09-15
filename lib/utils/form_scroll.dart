import 'package:flutter/widgets.dart';

/// Формыг шалгаад алдаатай бол ХАМГИЙН ДЭЭД талын алдаатай талбар руу гүйлгэнэ.
///
/// Урт формын доод талбаруудыг бөглөөд "Хадгалах" дарахад дээд талд
/// алгассан заавал бөглөх талбарын алдаа дэлгэцээс гадуур харагдахгүй үлдэж,
/// товч юу ч хийгээгүй мэт санагддаг байв.
bool validateAndScrollToError(GlobalKey<FormState> formKey) {
  final form = formKey.currentState;
  if (form == null) return false;
  final invalid = form.validateGranularly();
  if (invalid.isEmpty) return true;

  // Алдааны мөр зурагдсаны дараа байрлалыг хэмжинэ.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    BuildContext? target;
    double? topY;
    for (final field in invalid) {
      if (!field.mounted) continue;
      final box = field.context.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (topY == null || y < topY) {
        topY = y;
        target = field.context;
      }
    }
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  });
  return false;
}
