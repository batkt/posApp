import 'package:flutter_test/flutter_test.dart';

import 'package:posease/utils/tender_amount_input.dart';

void main() {
  group('Бэлэн төлөлтийн дүн — бутархай', () {
    test('төлөх дүн бутархай үед бүтнээр нь урьдчилан бөглөнө', () {
      // Тайлагнасан алдаа: `due.ceil()` хийдэг байсан тул 12,345.67 дээр
      // 12,346 бөглөгдөж, үлдсэн 0.33 нь "Хариулт" болж гардаг байв.
      final digits = TenderAmountInput.exactDigits(12345.67);
      expect(digits, '12345.67');
      expect(TenderAmountInput.value(digits), 12345.67);

      // Хариулт тэг байх ёстой.
      const due = 12345.67;
      expect(TenderAmountInput.value(digits) - due, closeTo(0, 0.0001));
    });

    test('бүхэл дүн дээр .00 нэмэхгүй', () {
      expect(TenderAmountInput.exactDigits(15000), '15000');
      expect(TenderAmountInput.exactDigits(0), '');
      expect(TenderAmountInput.exactDigits(-5), '');
      expect(TenderAmountInput.exactDigits(double.nan), '');
    });

    test('таслал нэг л удаа орно', () {
      var d = TenderAmountInput.press('123', '.');
      expect(d, '123.');
      d = TenderAmountInput.press(d, '.');
      expect(d, '123.');
      d = TenderAmountInput.press(d, '5');
      expect(d, '123.5');
    });

    test('хоосон дээр таслал дарвал 0. болно', () {
      expect(TenderAmountInput.press('', '.'), '0.');
    });

    test('аравтын 2 орноос хэтрэхгүй', () {
      var d = '10.99';
      d = TenderAmountInput.press(d, '9');
      expect(d, '10.99');
    });

    test('бүхэл хэсэг нь урт хязгаартай', () {
      final long = '9' * TenderAmountInput.maxLength;
      expect(TenderAmountInput.press(long, '9'), long);
    });

    test('устгах ба цэвэрлэх', () {
      expect(TenderAmountInput.press('123.4', '⌫'), '123.');
      expect(TenderAmountInput.press('', '⌫'), '');
      expect(TenderAmountInput.press('123.45', 'C'), '');
    });

    test('түргэн товч бутархайг хадгална', () {
      // Өмнө нь `int.tryParse` ашигладаг байсан тул бутархай нь тасарч,
      // 12,345.67 + 1,000 = 13,000 болдог байв.
      expect(TenderAmountInput.addQuick('12345.67', 1000), '13345.67');
      expect(TenderAmountInput.addQuick('', 5000), '5000');
    });

    test('дуусаагүй бутархайг харуулахдаа таслалыг хэвээр үлдээнэ', () {
      expect(TenderAmountInput.display('1234'), '1,234.00');
      // Таслал дарангуут алга болвол бутархай оруулах боломжгүй болно.
      expect(TenderAmountInput.display('1234.'), '1,234.');
      expect(TenderAmountInput.display('1234.5'), '1,234.5');
      expect(TenderAmountInput.display('1234.56'), '1,234.56');
      expect(TenderAmountInput.display(''), '0.00');
    });
  });
}
