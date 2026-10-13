// Models are faked through the package's internal test constructor.
// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/live_translate.dart';
import 'package:live_translate_example/language_picker.dart';
import 'package:live_translate_example/languages.dart';

import 'support/fakes.dart';

void main() {
  late FakeModelStore store;
  late LanguageChoice? result;
  late bool popped;

  setUp(() {
    store = FakeModelStore();
    result = null;
    popped = false;
  });

  /// Opens the picker from a home page, recording what it returns.
  Future<void> open(
    WidgetTester tester, {
    List<TranslateLanguage?> options = TranslateLanguage.values,
    TranslateLanguage? selected = TranslateLanguage.english,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await pickLanguage(
                context,
                title: 'Translate to',
                options: options,
                selected: selected,
                models: TranslationModels.withStore(store),
              );
              popped = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder row(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ListTile));

  testWidgets('search keeps only matching names', (tester) async {
    await open(tester);
    expect(find.text('Afrikaans'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'GER');
    await tester.pump();
    expect(find.text('German'), findsOneWidget);
    expect(find.text('Afrikaans'), findsNothing);
  });

  testWidgets('the current choice is first and marked', (tester) async {
    await open(tester, selected: TranslateLanguage.spanish);
    final first = tester.widget<ListTile>(find.byType(ListTile).first);
    expect((first.title! as Text).data, 'Spanish');
    expect(
      find.descendant(
        of: row('Spanish'),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('downloaded models are marked', (tester) async {
    // Tall enough to build every source row.
    tester.view
      ..physicalSize = const Size(400, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store.present.addAll({TranslateLanguage.english, TranslateLanguage.hindi});
    await open(tester, options: sourceOptions, selected: null);
    expect(find.text('German'), findsOneWidget);

    Finder mark(String name) => find.descendant(
      of: row(name),
      matching: find.byIcon(Icons.download_done),
    );
    expect(mark('English'), findsOneWidget);
    expect(mark('Hindi'), findsOneWidget);
    expect(mark('German'), findsNothing);
    expect(mark('Detect language'), findsNothing);
  });

  testWidgets('choosing a language returns it', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'german');
    await tester.pump();
    await tester.tap(find.text('German'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(result, (choice: TranslateLanguage.german));
  });

  testWidgets('choosing Detect language returns no language', (tester) async {
    await open(
      tester,
      options: sourceOptions,
      selected: TranslateLanguage.hindi,
    );
    final first = tester.widget<ListTile>(find.byType(ListTile).first);
    expect((first.title! as Text).data, 'Detect language');

    await tester.tap(find.text('Detect language'));
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(result, (choice: null));
  });

  testWidgets('going back returns nothing', (tester) async {
    await open(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(result, isNull);
  });
}
