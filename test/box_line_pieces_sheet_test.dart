import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/models/inventory_model.dart';
import 'package:posease/models/locale_model.dart';
import 'package:posease/models/sales_model.dart';
import 'package:posease/widgets/box_line_pieces_sheet.dart';
import 'package:provider/provider.dart';

Product _boxProduct({
  int uldegdel = 19,
  int negPerBox = 5,
}) =>
    Product(
      id: 'box_prod_1',
      name: 'Жазз бөмбөр',
      description: '',
      price: 5000,
      category: '',
      imageUrl: '',
      code: '10157',
      khemjikhNegj: 'хайрцаг',
      shirkheglekhEsekh: true,
      negKhairtsaganDahiShirhegiinToo: negPerBox,
      niitUne: 5000,
      uldegdel: uldegdel, // 19 boxes * 5 = 95 pieces
    );

Widget _buildTestApp({
  required SalesModel sales,
  required InventoryModel inv,
  required SaleItem item,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SalesModel>.value(value: sales),
      ChangeNotifierProvider<InventoryModel>.value(value: inv),
    ],
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
            onPressed: () => showBoxLinePiecesSheet(ctx, item),
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Хэмжих нэгж өөрчлөх — нэмэх хасах үйлдлүүд тэгш хэмтэй зөв ажиллана',
      (tester) async {
    final sales = SalesModel();
    final inv = InventoryModel();
    final product = _boxProduct(uldegdel: 19, negPerBox: 5);
    sales.addToSale(product);
    final item = sales.currentSaleItems.first;

    await tester.pumpWidget(_buildTestApp(sales: sales, inv: inv, item: item));
    await tester.pumpAndSettle();

    // Open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify title and info
    expect(find.text('Хэмжих нэгж өөрчлөх'), findsOneWidget);
    expect(find.text('5 ш'), findsOneWidget); // neg
    expect(find.text('95 ш'), findsOneWidget); // stock pieces (19 * 5)

    // Initial value in textfield is 5 (1 box * 5 pieces)
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);
    TextField tf = tester.widget<TextField>(inputFinder);
    expect(tf.controller?.text, '5');

    // Verify stepper buttons exist
    final stepperPlus = find.byIcon(Icons.add_rounded);
    final stepperMinus = find.byIcon(Icons.remove_rounded);
    expect(stepperPlus, findsOneWidget);
    expect(stepperMinus, findsOneWidget);

    // Verify symmetrical quick buttons exist in order
    expect(find.text('−5'), findsOneWidget);
    expect(find.text('−1'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);

    // 1. Test stepper + (increment by 1)
    await tester.tap(stepperPlus);
    await tester.pumpAndSettle();
    tf = tester.widget<TextField>(inputFinder);
    expect(tf.controller?.text, '6');

    // 2. Test stepper - (decrement by 1)
    await tester.tap(stepperMinus);
    await tester.pumpAndSettle();
    tf = tester.widget<TextField>(inputFinder);
    expect(tf.controller?.text, '5');

    // 3. Test quick +5 button
    await tester.tap(find.text('+5'));
    await tester.pumpAndSettle();
    tf = tester.widget<TextField>(inputFinder);
    expect(tf.controller?.text, '10');

    // 4. Test quick -5 button
    await tester.tap(find.text('−5'));
    await tester.pumpAndSettle();
    tf = tester.widget<TextField>(inputFinder);
    expect(tf.controller?.text, '5');

    // 5. Test quick -5 when value is 5 -> clamps to minimum 1
    await tester.tap(find.text('−5'));
    await tester.pumpAndSettle();
    tf = tester.widget<TextField>(inputFinder);
    expect(tf.controller?.text, '1');

    // At 1, minus buttons should be disabled
    final minusBtn = tester.widget<FilledButton>(
      find.ancestor(of: find.text('−1'), matching: find.byType(FilledButton)),
    );
    expect(minusBtn.onPressed, isNull);

    // 6. Test save button updates sales model
    await tester.tap(stepperPlus); // 1 -> 2
    await tester.pumpAndSettle();
    tf = tester.widget<TextField>(inputFinder);
    expect(tf.controller?.text, '2');

    await tester.tap(find.text('Хадгалах'));
    await tester.pumpAndSettle();

    // Sheet should close and sales model should have updated pieces
    expect(sales.currentSaleItems.first.boxPiecesSold, 2.0);
  });
}
