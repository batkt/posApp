import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:posease/models/auth_model.dart';
import 'package:posease/models/locale_model.dart';
import 'package:posease/screens/main/forgot_password_screen.dart';

Widget _app() => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(create: (_) => LocaleModel()),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('mn')],
        home: const ForgotPasswordScreen(),
      ),
    );

void main() {
  testWidgets('нууц үг сэргээх дэлгэц алдаагүй зурагдана', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Нууц үгээ сэргээх'), findsOneWidget);
    expect(find.text('Код илгээх'), findsOneWidget);
    // Явцын заагчийн хоёр алхам.
    expect(find.text('Дугаар'), findsOneWidget);
    expect(find.text('Шинэ нууц үг'), findsOneWidget);
  });

  testWidgets('нарийн дэлгэц дээр ч давхцахгүй', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'явцын заагч нарийн дэлгэцэд халихгүй');
  });

  testWidgets('утасны дугаарын шалгалт дэлгэц дээр ажиллана', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '123');
    await tester.tap(find.text('Код илгээх'));
    await tester.pumpAndSettle();

    expect(find.textContaining('8 оронтой'), findsOneWidget);
  });
}
