import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/live_translate.dart';
import 'package:live_translate_example/text_sheet.dart';

TranslatedParagraph _line(String translated, String source, int i) =>
    TranslatedParagraph(
      id: 'p$i',
      sourceText: source,
      translatedText: translated,
      sourceLanguage: TranslateLanguage.spanish,
      rect: Rect.fromLTWH(0, 40.0 * i, 100, 30),
    );

void main() {
  late ValueNotifier<List<TranslatedParagraph>?> paragraphs;
  late List<String> clipboard;

  setUp(() {
    paragraphs = ValueNotifier([
      _line('Exit', 'Salida', 0),
      _line('Entrance', 'Entrada', 1),
    ]);
    clipboard = [];
  });

  tearDown(() => paragraphs.dispose());

  Future<void> openSheet(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTextSheet(context, paragraphs),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists each translation over its original', (tester) async {
    await openSheet(tester);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(
      [for (final t in tiles) (t.title! as Text).data],
      ['Exit', 'Entrance'],
    );
    expect(
      [for (final t in tiles) (t.subtitle! as Text).data],
      ['Salida', 'Entrada'],
    );
  });

  testWidgets('copies one translation', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byTooltip('Copy').first);
    await tester.pump();
    expect(clipboard, ['Exit']);
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('copies every translation', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Copy all'));
    await tester.pump();
    expect(clipboard, ['Exit\n\nEntrance']);
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('follows a new translation', (tester) async {
    await openSheet(tester);
    paragraphs.value = [_line('Ausgang', 'Salida', 0)];
    await tester.pump();
    expect(find.text('Ausgang'), findsOneWidget);
    expect(find.text('Exit'), findsNothing);
  });

  testWidgets('the confirmation goes away', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Copy all'));
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Copied'), findsNothing);
  });

  testWidgets('starts at half the screen, not full height', (tester) async {
    await openSheet(tester);
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getTopLeft(find.text('Copy all')).dy,
      greaterThan(height * 0.4),
    );
  });

  testWidgets('closes when the view resumes', (tester) async {
    await openSheet(tester);
    paragraphs.value = null;
    await tester.pumpAndSettle();
    expect(find.text('Copy all'), findsNothing);
  });
}
