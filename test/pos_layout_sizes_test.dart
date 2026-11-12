import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/auth_model.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/inventory_model.dart';
import 'package:posease/models/locale_model.dart';
import 'package:posease/models/pos_session.dart';
import 'package:posease/models/sales_model.dart';
import 'package:posease/screens/pos/pos_screen.dart';
import 'package:posease/screens/pos/cashier_main_screen.dart';
import 'package:provider/provider.dart';

/// Кассын ПОС дэлгэц утас, Z Fold (хаалттай/нээлттэй), таблет, десктоп
/// хэмжээнд layout overflow (RenderFlex) алдаагүй зурагдаж буйг шалгана.
/// Сагсанд бараатай үед тооцооны хэсэг ч зурагдана.
void main() {
  const khemjeenuud = <String, Size>{
    'утас 390x844': Size(390, 844),
    'Z Fold хаалттай 344x882': Size(344, 882),
    'Z Fold нээлттэй 673x841': Size(673, 841),
    'Z Fold хэвтээ 841x673': Size(841, 673),
    'таблет босоо 800x1280': Size(800, 1280),
    'таблет хэвтээ 1280x800': Size(1280, 800),
    'десктоп 1920x1080': Size(1920, 1080),
  };

  Product baraa(int i) => Product(
        id: 'p$i',
        name: 'Туршилтын бараа $i урт нэртэй',
        description: '',
        price: 1000.0 * i,
        category: 'Бүгд',
        imageUrl: '',
        code: '100$i',
      );

  for (final entry in khemjeenuud.entries) {
    testWidgets('ПОС layout — ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthModel();
      auth.setPosSessionForTesting(const PosSession(
        baiguullagiinId: 'b-1',
        salbariinId: 's-1',
        ajiltan: {'_id': 'aj-1', 'ner': 'Кассчин'},
      ));
      final sales = SalesModel();
      final inventory = InventoryModel();
      for (var i = 1; i <= 8; i++) {
        inventory.addProduct(baraa(i), initialStock: 50);
      }
      for (var i = 1; i <= 4; i++) {
        sales.addToSale(baraa(i));
      }

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleModel()),
          ChangeNotifierProvider<AuthModel>.value(value: auth),
          ChangeNotifierProvider<SalesModel>.value(value: sales),
          ChangeNotifierProvider<InventoryModel>.value(value: inventory),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('mn'), Locale('en')],
          locale: Locale('mn'),
          home: Scaffold(body: POSScreen(cashierMode: true)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Хоёр алхамт урсгалд (нарийн дэлгэц) сагс/төлбөрийн хуудас руу шилжинэ
      final pageView = find.byType(PageView);
      if (pageView.evaluate().isNotEmpty) {
        final controller =
            (tester.widget<PageView>(pageView.first)).controller!;
        controller.jumpToPage(1);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Төлбөр төлөх'), findsOneWidget,
            reason: 'тооцооны хэсэг харагдах ёстой');
        // Тооцооны (доод) хэсэг дэлгэцийн 40%-иас ихгүй — барааны
        // жагсаалтад зай үлдэнэ.
        final niitTop = tester.getTopLeft(find.text('Нийт төлөх').first).dy;
        final dooduurOrgon = entry.value.height - niitTop;
        // ignore: avoid_print
        print('${entry.key}: тооцооны хэсэг ${dooduurOrgon.round()}px '
            '(${(dooduurOrgon / entry.value.height * 100).round()}%)');
        expect(dooduurOrgon, lessThan(entry.value.height * 0.4));
      }

      // Overflow гарвал tester.takeException() алдаа буцаана
      expect(tester.takeException(), isNull);
    });
  }


  for (final entry in khemjeenuud.entries) {
    testWidgets('Кассын бүрхүүл (цэстэй) — ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = AuthModel();
      auth.setPosSessionForTesting(const PosSession(
        baiguullagiinId: 'b-1',
        salbariinId: 's-1',
        ajiltan: {'_id': 'aj-1', 'ner': 'Кассчин'},
      ));
      final sales = SalesModel();
      final inventory = InventoryModel();
      for (var i = 1; i <= 8; i++) {
        inventory.addProduct(baraa(i), initialStock: 50);
      }
      for (var i = 1; i <= 4; i++) {
        sales.addToSale(baraa(i));
      }

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleModel()),
          ChangeNotifierProvider<AuthModel>.value(value: auth),
          ChangeNotifierProvider<SalesModel>.value(value: sales),
          ChangeNotifierProvider<InventoryModel>.value(value: inventory),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('mn'), Locale('en')],
          locale: Locale('mn'),
          home: CashierMainScreen(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final w = entry.value.width;
      // ≥600px (нээлттэй Z Fold, таблет): бараа + баруун талын сагсны
      // самбар нэг дэлгэцэнд (Тооцоо, Хүлээлгэ, Төлбөр төлөх).
      if (w >= 600) {
        expect(find.byType(PageView), findsNothing,
            reason: 'хоёр алхамт биш, хажуугийн сагсны самбартай');
        expect(find.text('Одоогийн касс'), findsOneWidget,
            reason: 'баруун талын сагсны самбар харагдана');
      } else {
        expect(find.byType(PageView), findsOneWidget,
            reason: 'утсанд хоёр алхамт урсгал');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
