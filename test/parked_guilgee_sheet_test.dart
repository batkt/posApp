import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posease/models/locale_model.dart';
import 'package:posease/services/guilgee_service.dart';
import 'package:posease/utils/mnt_amount_formatter.dart';
import 'package:posease/utils/mongolian_date_formatter.dart';

void main() {
  testWidgets('ParkedGuilgeeRow layout renders transaction, date, line count and amount cleanly', (tester) async {
    final row = ParkedGuilgeeRow({
      '_id': 'test_mongo_1',
      'guilgeeniiDugaar': 'БД26092413',
      'ognoo': '2026-09-24T10:12:00.000Z',
      'niitUne': 1327410.0,
      'baraanuud': List.generate(21, (i) => {'_id': '$i'}),
    });

    final whenStr =
        '${MongolianDateFormatter.formatSalesHistorySectionDate(row.ognoo)} · '
        '${MongolianDateFormatter.formatTime(row.ognoo, seconds: false)}';

    bool deleteTapped = false;
    bool recallTapped = false;

    await tester.pumpWidget(
      MaterialApp(
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
            builder: (context) {
              final cs = Theme.of(context).colorScheme;
              final tt = Theme.of(context).textTheme;
              final l10n = AppLocalizations.of(context);

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => recallTapped = true,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.pause_circle_filled_rounded,
                                    color: cs.primary,
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.guilgeeniiDugaar,
                                      style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      whenStr,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: l10n.tr('pos_park_delete'),
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: cs.error,
                                  size: 22,
                                ),
                                onPressed: () => deleteTapped = true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 16,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.tr('pos_park_line_count').replaceAll('{n}', '${row.lineCount}'),
                                  style: tt.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  MntAmountFormatter.formatTugrikSpaced(row.niitUne),
                                  style: tt.titleMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: cs.primary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all contents are present
    expect(find.text('БД26092413'), findsOneWidget);
    expect(find.textContaining('2026-09-24'), findsOneWidget);
    expect(find.text('21 бараа'), findsOneWidget);
    expect(find.text('1,327,410.00 ₮'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    // Tap delete button only invokes delete
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    expect(deleteTapped, isTrue);
    expect(recallTapped, isFalse);

    // Tap card invokes recall
    await tester.tap(find.text('БД26092413'));
    expect(recallTapped, isTrue);
  });
}
