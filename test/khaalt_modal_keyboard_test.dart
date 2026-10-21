import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/auth_model.dart';
import 'package:posease/models/locale_model.dart';
import 'package:posease/models/pos_session.dart';
import 'package:posease/screens/main/khaalt_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('showKhaaltModal — гарын гарч ирэх үед мөнгөн дүнгийн оролтууд харагдаж, засагдана', (tester) async {
    tester.view.physicalSize = const Size(390, 844); // iPhone standard size
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authModel = AuthModel();
    // Simulate valid pos session
    authModel.setPosSessionForTesting(const PosSession(
      baiguullagiinId: 'b-1',
      salbariinId: 's-1',
      ajiltan: {
        '_id': 'aj-1',
        'ner': 'Кассчин',
        'name': 'Кассчин',
        'tokhirgoo': {'khaaltAshiglakhEsekh': true},
      },
    ));

    await tester.pumpWidget(ChangeNotifierProvider<AuthModel>.value(
      value: authModel,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('mn'), Locale('en')],
        locale: const Locale('mn'),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showKhaaltModal(ctx),
              child: const Text('Open Khaalt'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Khaalt'));
    // Wait for modal transition and _load() to complete
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify dialog title is visible
    expect(find.text('Касс хаалт'), findsOneWidget);
    // Verify denomination inputs exist
    expect(find.text('20,000.00₮'), findsOneWidget);
    expect(find.text('10,000.00₮'), findsOneWidget);

    // Now simulate virtual keyboard opening (viewInsets.bottom = 336)
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
    await tester.pumpAndSettle();

    // Denominations MUST still be visible even when keyboard is open!
    expect(find.text('20,000.00₮'), findsOneWidget);

    // Find the TextField next to 20,000.00₮ and enter a count
    final firstTextField = find.byType(TextField).first;
    await tester.enterText(firstTextField, '5');
    await tester.pumpAndSettle();

    // Verify total updated to 100,000.00₮ in the compact footer
    expect(find.textContaining('100,000.00₮'), findsWidgets);

    // Verify submit button is visible in the compact bar
    expect(find.text('Хаалт хийх'), findsOneWidget);
  });
}
