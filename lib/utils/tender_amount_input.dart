import 'mnt_amount_formatter.dart';

/// Бэлэн төлөлтийн товчлуурт бичигдэх дүнгийн цэвэр логик.
///
/// Төлөв нь ганц "түүхий" мөр: зөвхөн цифр болон нэг таслал ('.') агуулна
/// (жишээ нь `"12345.6"`). Дүнг бүхэл тоогоор барихад төлөх дүнгийн
/// бутархай хэсэг "Хариулт" болж гарч ирдэг байсан тул бутархайг бүрэн
/// дэмжинэ.
abstract final class TenderAmountInput {
  TenderAmountInput._();

  /// Мөнгөн дүнгийн аравтын орны дээд хязгаар.
  static const int maxFractionDigits = 2;

  /// Нэг мөрөнд зөвшөөрөх тэмдэгтийн дээд хязгаар.
  static const int maxLength = 14;

  /// Дүнг БҮТНЭЭР нь (бутархайтай нь) товчлуурын мөр болгоно.
  ///
  /// Бүхэл дүн дээр `.00` гэж бичихгүй — кассчин дээр нь шууд цифр нэмж
  /// бичихэд саад болно.
  static String exactDigits(double amount) {
    if (!amount.isFinite || amount <= 0) return '';
    final fixed = amount.toStringAsFixed(maxFractionDigits);
    if (fixed.endsWith('.00')) {
      return fixed.substring(0, fixed.length - 3);
    }
    return fixed;
  }

  /// Тоон утга.
  static double value(String digits) =>
      double.tryParse(digits.isEmpty ? '0' : digits) ?? 0;

  /// Нэг товч дарсны дараах шинэ мөр. `'C'` цэвэрлэх, `'⌫'` устгах,
  /// `'.'` таслал, бусад нь цифр.
  static String press(String digits, String key) {
    switch (key) {
      case 'C':
        return '';
      case '⌫':
        return digits.isEmpty
            ? digits
            : digits.substring(0, digits.length - 1);
      case '.':
        // Нэг л таслал; эхэнд дарвал "0." болгоно.
        if (digits.contains('.')) return digits;
        return digits.isEmpty ? '0.' : '$digits.';
      default:
        final dot = digits.indexOf('.');
        if (dot >= 0 && digits.length - dot - 1 >= maxFractionDigits) {
          return digits; // аравтын 2 орноос хэтрүүлэхгүй
        }
        if (digits.length >= maxLength) return digits;
        return digits + key;
    }
  }

  /// Түргэн товч (+1,000 г.м) — бутархай хэсгийг ХАДГАЛНА.
  static String addQuick(String digits, num add) =>
      exactDigits(value(digits) + add);

  /// Дэлгэцэнд харагдах хэлбэр: мянгатын тусгаарлагчтай, гэхдээ дуусаагүй
  /// бутархайг (`"1234."`, `"1234.5"`) хэвээр нь үлдээнэ — эс тэгвээс
  /// таслал дарангуут алга болж, бутархай оруулах боломжгүй болно.
  static String display(String digits) {
    if (digits.isEmpty) return MntAmountFormatter.format(0);
    final dot = digits.indexOf('.');
    if (dot < 0) return MntAmountFormatter.format(value(digits));
    final head = digits.substring(0, dot);
    final intPart = double.tryParse(head.isEmpty ? '0' : head) ?? 0;
    final intText = MntAmountFormatter.format(intPart);
    // [MntAmountFormatter.format] нь ".00"-г үргэлж нэмдэг тул бүхэл
    // хэсгийг нь л таслан авна.
    final intOnly = intText.contains('.')
        ? intText.substring(0, intText.indexOf('.'))
        : intText;
    return '$intOnly.${digits.substring(dot + 1)}';
  }
}
