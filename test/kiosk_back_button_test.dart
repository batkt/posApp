import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:posease/models/auth_model.dart';
import 'package:posease/models/locale_model.dart';
import 'package:posease/widgets/kiosk_drawer.dart';

Widget _wrap(Widget home) {
  return MultiProvider(
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
      home: home,
    ),
  );
}

const _page = KioskDrawerStackedPage(
  mobileStaffShell: true,
  titleKey: 'pos_sale_promo',
  body: SizedBox.shrink(),
);

void main() {
  testWidgets('цэснээс нээсэн хуудас БУЦАХ сумтай байна', (tester) async {
    await tester.pumpWidget(
      _wrap(const Scaffold(body: SizedBox.shrink())),
    );
    // Локалчлалын delegate нь async ачаалагддаг тул эхний фрэймд бие нь
    // хараахан баригдаагүй байдаг.
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(Scaffold))).push(
      MaterialPageRoute<void>(builder: (_) => _page),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget,
        reason: 'буцах боломжтой үед буцах сум харагдана');
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('буцах хуудасгүй үед цэсний товч хэвээр үлдэнэ', (tester) async {
    await tester.pumpWidget(_wrap(_page));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget,
        reason: 'үндсэн хуудас — буцах газаргүй тул цэс хэвээр');
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
