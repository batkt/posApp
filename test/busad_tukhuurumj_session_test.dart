import 'package:flutter_test/flutter_test.dart';
import 'package:posease/services/api_service.dart';

// Нэг эрхээр нэг төхөөрөмж — posBack `sessShalgakh` мессежийг танина.
void main() {
  const msg =
      'Таны эрхээр өөр төхөөрөмжөөс нэвтэрсэн тул энэ төхөөрөмжөөс гарлаа';

  test('өөр төхөөрөмжөөс нэвтэрсэн мессеж гаралт үүсгэнэ', () {
    expect(ApiService.isBusadTukhuurumjMessage(msg), isTrue);
    expect(ApiService.isSessionExpiredMessage(msg), isTrue);
  });

  test('ердийн алдаа гаралт үүсгэхгүй', () {
    expect(ApiService.isBusadTukhuurumjMessage('Үлдэгдэл хүрэлцэхгүй'), isFalse);
    expect(ApiService.isSessionExpiredMessage('Үлдэгдэл хүрэлцэхгүй'), isFalse);
  });
}
