import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posease/services/inactivity_monitor.dart';

void main() {
  group('Идэвхгүй байдлын автомат гаралт', () {
    test('15 минут идэвхгүй байвал гаралт дуудагдана', () {
      fakeAsync((async) {
        var loggedOut = 0;
        InactivityMonitor(onTimeout: () => loggedOut++)..start();

        async.elapse(const Duration(minutes: 14, seconds: 59));
        expect(loggedOut, 0, reason: '15 минут болоогүй');

        async.elapse(const Duration(seconds: 2));
        expect(loggedOut, 1);
      });
    });

    test('үйлдэл хийх бүрд тоолуур эхнээсээ эхэлнэ', () {
      fakeAsync((async) {
        var loggedOut = 0;
        final m = InactivityMonitor(onTimeout: () => loggedOut++)..start();

        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(minutes: 10));
          m.registerActivity();
        }
        expect(loggedOut, 0, reason: '10 минут тутам үйлдэл хийсэн');

        async.elapse(const Duration(minutes: 16));
        expect(loggedOut, 1);
      });
    });

    test('зогсоосны дараа гаралт болохгүй', () {
      fakeAsync((async) {
        var loggedOut = 0;
        InactivityMonitor(onTimeout: () => loggedOut++)
          ..start()
          ..stop();

        async.elapse(const Duration(hours: 2));
        expect(loggedOut, 0);
      });
    });

    test('гаралт зөвхөн НЭГ удаа дуудагдана', () {
      fakeAsync((async) {
        var loggedOut = 0;
        InactivityMonitor(onTimeout: () => loggedOut++)..start();

        async.elapse(const Duration(hours: 3));
        expect(loggedOut, 1, reason: 'давтан гаралт хийхгүй');
      });
    });

    test('эхлүүлээгүй бол хугацаа өнгөрөхөд ч гаралт болохгүй', () {
      fakeAsync((async) {
        var loggedOut = 0;
        InactivityMonitor(onTimeout: () => loggedOut++);
        async.elapse(const Duration(hours: 1));
        expect(loggedOut, 0);
      });
    });
  });
}
