import 'package:flutter_test/flutter_test.dart';
import 'package:posease/utils/password_reset_rules.dart';

void main() {
  group('Утасны дугаарын шалгалт', () {
    test('8 оронтой монгол дугаар зөвшөөрөгдөнө', () {
      expect(PasswordResetRules.phoneError('88112233'), isNull);
      expect(PasswordResetRules.phoneError(' 99887766 '), isNull);
    });

    test('хоосон дугаарыг хориглоно', () {
      expect(PasswordResetRules.phoneError(''), isNotNull);
      expect(PasswordResetRules.phoneError('   '), isNotNull);
    });

    test('8-аас цөөн/олон оронтой дугаарыг хориглоно', () {
      expect(PasswordResetRules.phoneError('8811223'), isNotNull);
      expect(PasswordResetRules.phoneError('881122334'), isNotNull);
    });

    test('үсэг агуулсан дугаарыг хориглоно', () {
      expect(PasswordResetRules.phoneError('88AB2233'), isNotNull);
    });
  });

  group('Шинэ нууц үгийн шалгалт', () {
    test('6-аас дээш тэмдэгттэй нууц үг зөвшөөрөгдөнө', () {
      expect(PasswordResetRules.passwordError('abc123'), isNull);
    });

    test('хэт богино нууц үгийг хориглоно', () {
      expect(PasswordResetRules.passwordError('123'), isNotNull);
      expect(PasswordResetRules.passwordError(''), isNotNull);
    });

    test('зөвхөн хоосон зайнаас бүрдсэн нууц үгийг хориглоно', () {
      expect(PasswordResetRules.passwordError('        '), isNotNull);
    });
  });

  group('Нууц үг давтахын шалгалт', () {
    test('ижил бол алдаагүй', () {
      expect(PasswordResetRules.confirmError('abc123', 'abc123'), isNull);
    });

    test('зөрвөл алдаа — бичих алдаанаас болж бүдэрдгийг сэргийлнэ', () {
      expect(PasswordResetRules.confirmError('abc123', 'abc124'), isNotNull);
    });

    test('хоосон давталтыг хориглоно', () {
      expect(PasswordResetRules.confirmError('abc123', ''), isNotNull);
    });
  });

  group('Баталгаажуулах кодын шалгалт', () {
    test('код оруулсан бол алдаагүй', () {
      expect(PasswordResetRules.codeError('1234'), isNull);
    });

    test('хоосон кодыг хориглоно', () {
      expect(PasswordResetRules.codeError('  '), isNotNull);
    });
  });
}
