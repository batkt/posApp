import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posease/utils/form_scroll.dart';

void main() {
  testWidgets('алгассан дээд талбар руу автоматаар гүйлгэнэ', (tester) async {
    final formKey = GlobalKey<FormState>();
    final scroll = ScrollController();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: scroll,
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  key: const Key('code'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Оруулна уу' : null,
                ),
                const SizedBox(height: 3000),
                TextFormField(initialValue: '6'),
              ],
            ),
          ),
        ),
      ),
    ));

    // Хэрэглэгч доош гүйлгээд доод талбарыг бөглөсөн.
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(scroll.offset, greaterThan(0));

    expect(validateAndScrollToError(formKey), isFalse);
    await tester.pumpAndSettle();

    expect(scroll.offset, 0);
    expect(find.text('Оруулна уу'), findsOneWidget);
  });

  testWidgets('алдаагүй бол гүйлгэхгүй, true буцаана', (tester) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: TextFormField(initialValue: 'ok'),
        ),
      ),
    ));

    expect(validateAndScrollToError(formKey), isTrue);
  });
}
