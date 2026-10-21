import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/customer_model.dart';
import 'package:posease/models/locale_model.dart';
import 'package:posease/screens/main/customers_screen.dart';
import 'package:provider/provider.dart';

Customer _customerWithPurchases({
  int totalPurchases = 3,
  double totalSpent = 54000.0,
}) {
  return Customer(
    id: 'cust-123',
    name: 'Болд',
    phone: '99112233',
    createdAt: DateTime.now(),
    totalPurchases: totalPurchases,
    totalSpent: totalSpent,
  );
}

void main() {
  testWidgets('Худалдан авалт / гүйлгээтэй харилцагчийн дэлгэрэнгүй цонх — устгах товч дээр анхааруулга өгч хориглоно', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final customer = _customerWithPurchases();
    final model = CustomerModel();
    model.addCustomer(customer);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('mn'), Locale('en')],
      home: Scaffold(
        body: ChangeNotifierProvider<CustomerModel>.value(
          value: model,
          child: SizedBox(
            height: 1200,
            width: 800,
            child: CustomerDetailsSheet(customer: customer),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify detail sheet is visible
    expect(find.text('Болд'), findsOneWidget);
    final ustgakhBtn = find.widgetWithText(OutlinedButton, 'Устгах');
    expect(ustgakhBtn, findsOneWidget);

    // Scroll to delete button and tap
    await tester.ensureVisible(ustgakhBtn);
    await tester.pumpAndSettle();
    await tester.tap(ustgakhBtn);
    await tester.pumpAndSettle();

    // Should NOT show delete confirmation dialog ("«Болд» харилцагчийг устгах уу?")
    expect(find.text('«Болд» харилцагчийг устгах уу?'), findsNothing);

    // Should show warning snackbar
    expect(
      find.text('Уучлаарай, худалдан авалт эсвэл гүйлгээ хийгдсэн харилцагчийг устгах боломжгүй!'),
      findsOneWidget,
    );

    // Let the snackbar auto-dismiss timer expire cleanly
    await tester.pump(const Duration(seconds: 5));
  });
}
