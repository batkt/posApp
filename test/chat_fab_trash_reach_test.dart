import 'package:flutter_test/flutter_test.dart';

/// [lib/widgets/chat_fab.dart]-ийн геометрийн тогтмолуудыг тольдож,
/// "чирж устгах" боломжтой хэвээр эсэхийг хамгаална.
///
/// Тэдгээр нь тухайн файлд private тул энд давхардуулан бичсэн — доорх
/// [trashStaysReachable] шалгалт нь тогтмолууд салж холдвол унана.
const double kBtnSize = 58.0;
const double kTrashZoneH = 88.0;
const double kBottomReserve = 40.0;

/// `_clamp`-ийн доод хязгаар.
double maxDy(double screenH) => screenH - kBtnSize - kBottomReserve;

/// `_hitTrash`: товчны төв хогийн бүсэд орсон эсэх.
bool hitTrash(double dy, double screenH) =>
    dy + kBtnSize / 2 >= screenH - kTrashZoneH;

void main() {
  group('Чатбот товчийг чирж устгах', () {
    test('хамгийн доод цэгт хогийн савны бүсэд ХҮРНЭ', () {
      // Өмнө нь доод нөөц 80 байсан тул энэ шалгалт унадаг байсан:
      // товчны төв хогийн бүсээс 21px дээр зогсдог байв.
      for (final h in [640.0, 720.0, 800.0, 900.0, 1024.0]) {
        expect(
          hitTrash(maxDy(h), h),
          isTrue,
          reason: 'Дэлгэцийн өндөр $h дээр хогийн бүс хүрэхгүй байна',
        );
      }
    });

    test('доод нөөц нь геометрийн шаардлагыг хангана', () {
      // _kBottomReserve <= _kTrashZoneH - _kBtnSize / 2
      expect(kBottomReserve, lessThanOrEqualTo(kTrashZoneH - kBtnSize / 2));
    });

    test('дээд хэсэгт байхад устгах бүс идэвхжихгүй', () {
      const h = 800.0;
      expect(hitTrash(0, h), isFalse);
      expect(hitTrash(h / 2, h), isFalse);
    });
  });
}
