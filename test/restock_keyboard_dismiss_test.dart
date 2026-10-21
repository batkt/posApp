import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/cart_model.dart';
import 'package:posease/screens/main/restock_screen.dart';

Product _testProduct() => const Product(
      id: 'p1',
      name: 'Тест бараа',
      description: '',
      price: 1500,
      urtugUne: 1000,
      category: 'Ерөнхий',
      imageUrl: '',
      uldegdel: 5,
    );

void main() {
  testWidgets('Худалдан авалтын цонх — ListView нь scroll drag үед гар хаана', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RestockScreen(
        products: [_testProduct()],
        title: 'Шинэ худалдан авалт',
      ),
    ));

    final listViewFinder = find.byType(ListView);
    expect(listViewFinder, findsOneWidget);

    final listView = tester.widget<ListView>(listViewFinder);
    expect(
      listView.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  testWidgets('Худалдан авалтын цонх — тоо оруулах талбарт фокус авсны дараа гадуур дарахад фокус арилгана', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RestockScreen(
        products: [_testProduct()],
        title: 'Шинэ худалдан авалт',
      ),
    ));

    final textFieldFinder = find.widgetWithText(TextField, '1');
    expect(textFieldFinder, findsWidgets);

    // Tap the first field ("Тоо")
    await tester.tap(textFieldFinder.first);
    await tester.pump();

    final focusScope = FocusScope.of(tester.element(textFieldFinder.first));
    expect(focusScope.hasFocus, isTrue);

    // Tap outside (e.g. on the title or background)
    await tester.tap(find.text('Шинэ худалдан авалт'));
    await tester.pump();

    // Focus is successfully removed / unfocused
    expect(focusScope.hasPrimaryFocus, isFalse);
  });
}
