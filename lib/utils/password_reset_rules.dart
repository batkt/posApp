/// Нууц үг сэргээх урсгалын шалгалтууд.
///
/// Дэлгэцээс ТУСГААРЛАВ: өмнө нь "хоосон эсэх"-ээс өөр шалгалт байгаагүй тул
/// буруу форматтай дугаараар SMS хүсэх, эсвэл бичих алдаатай шинэ нууц үг
/// тохируулаад системээсээ гарцаагүй түгжигдэх боломжтой байв.
abstract final class PasswordResetRules {
  /// Монголын гар утасны дугаар — 8 орон.
  static const int phoneLength = 8;

  /// Хамгийн богино нууц үгийн урт.
  static const int minPasswordLength = 6;

  static String? phoneError(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Утасны дугаар оруулна уу';
    if (!RegExp(r'^\d+$').hasMatch(v)) {
      return 'Утасны дугаар зөвхөн тооноос бүрдэнэ';
    }
    if (v.length != phoneLength) {
      return 'Утасны дугаар $phoneLength оронтой байх ёстой';
    }
    return null;
  }

  static String? codeError(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Баталгаажуулах код оруулна уу';
    return null;
  }

  static String? passwordError(String? value) {
    final v = value ?? '';
    if (v.trim().isEmpty) return 'Шинэ нууц үгээ оруулна уу';
    if (v.length < minPasswordLength) {
      return 'Нууц үг хамгийн багадаа $minPasswordLength тэмдэгт байна';
    }
    return null;
  }

  static String? confirmError(String? password, String? confirm) {
    final c = confirm ?? '';
    if (c.isEmpty) return 'Нууц үгээ давтаж оруулна уу';
    if (c != (password ?? '')) return 'Нууц үг таарахгүй байна';
    return null;
  }
}
