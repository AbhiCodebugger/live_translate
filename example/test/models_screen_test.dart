// The tests manage fake models through the package's internal test seam.
// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/live_translate.dart';
import 'package:live_translate_example/models_screen.dart';

import 'support/fakes.dart';

void main() {
  late FakeModelStore store;

  setUp(() {
    store = FakeModelStore()
      ..present.addAll({TranslateLanguage.english, TranslateLanguage.hindi});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // Tall enough to build every language without scrolling.
    tester.view
      ..physicalSize = const Size(400, 6000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: ModelsScreen(models: TranslationModels.withStore(store)),
      ),
    );
    await tester.pump();
  }

  /// The language names listed after [header], up to the next header or
  /// the end.
  List<String> section(WidgetTester tester, String header) {
    final top = tester.getTopLeft(find.text(header)).dy;
    final nextHeader = header == 'On this phone'
        ? tester.getTopLeft(find.text('Available')).dy
        : double.infinity;
    final tiles = tester.widgetList<ListTile>(
      find.byWidgetPredicate((w) => w is ListTile && w.key is ValueKey),
    );
    return [
      for (final tile in tiles)
        if (tester.getTopLeft(find.byWidget(tile)).dy case final y
            when y > top && y < nextHeader)
          (tile.title! as Text).data!,
    ];
  }

  /// Lets the gated downloads finish. The gate was made in `setUp`, outside
  /// the test's fake time, so its completion runs on real async.
  Future<void> finishDownloads(WidgetTester tester) async {
    store.downloadGate.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();
  }

  Finder buttonFor(String language, String tooltip) => find.descendant(
    of: find.widgetWithText(ListTile, language),
    matching: find.byTooltip(tooltip),
  );

  testWidgets('lists models on the phone, then the rest', (tester) async {
    await pumpScreen(tester);
    expect(section(tester, 'On this phone'), ['English', 'Hindi']);
    final available = section(tester, 'Available');
    expect(available, contains('German'));
    expect(available, isNot(contains('English')));
    expect(available, [...available]..sort());
    expect(buttonFor('English', 'Delete'), findsOneWidget);
    expect(buttonFor('German', 'Download'), findsOneWidget);
  });

  testWidgets('downloads with a progress indicator', (tester) async {
    await pumpScreen(tester);
    await tester.tap(buttonFor('German', 'Download'));
    await tester.pump();
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'German'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(store.downloads, [TranslateLanguage.german]);

    await finishDownloads(tester);
    expect(section(tester, 'On this phone'), ['English', 'German', 'Hindi']);
    expect(buttonFor('German', 'Delete'), findsOneWidget);
  });

  testWidgets('deletes a model', (tester) async {
    await pumpScreen(tester);
    await tester.tap(buttonFor('Hindi', 'Delete'));
    await tester.pump();
    expect(store.present, isNot(contains(TranslateLanguage.hindi)));
    expect(section(tester, 'On this phone'), ['English']);
    expect(section(tester, 'Available'), contains('Hindi'));
  });

  testWidgets('a failed download says so and can be retried', (tester) async {
    store.downloadError = const ModelNotDownloaded(TranslateLanguage.german);
    await pumpScreen(tester);
    await tester.tap(buttonFor('German', 'Download'));
    await tester.pump();
    await finishDownloads(tester);
    expect(find.text("Couldn't download German"), findsOneWidget);
    expect(buttonFor('German', 'Download'), findsOneWidget);
    expect(section(tester, 'Available'), contains('German'));
  });

  testWidgets('downloads on any network by default', (tester) async {
    await pumpScreen(tester);
    final wifi = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(wifi.value, isFalse);
    await tester.tap(buttonFor('German', 'Download'));
    await tester.pump();
    expect(store.wifiOnly, [false]);
  });

  testWidgets('downloads on Wi-Fi only when switched on', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Wi-Fi only'));
    await tester.pump();
    await tester.tap(buttonFor('German', 'Download'));
    await tester.pump();
    expect(store.wifiOnly, [true]);
  });
}
