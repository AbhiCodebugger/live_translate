import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/live_translate.dart';

import 'support/fakes.dart';

void main() {
  late FakeModelStore store;
  late TranslationModels models;

  setUp(() {
    store = FakeModelStore();
    models = TranslationModels.withStore(store);
  });

  test('reports whether a model is downloaded', () async {
    store.present.add(TranslateLanguage.hindi);
    expect(await models.isDownloaded(TranslateLanguage.hindi), isTrue);
    expect(await models.isDownloaded(TranslateLanguage.marathi), isFalse);
  });

  test('requires Wi-Fi by default', () async {
    await models.download(TranslateLanguage.hindi);
    expect(store.downloads, [(TranslateLanguage.hindi, true)]);
  });

  test('allows mobile data when asked', () async {
    await models.download(TranslateLanguage.hindi, wifiOnly: false);
    expect(store.downloads, [(TranslateLanguage.hindi, false)]);
  });

  test('a failed download throws ModelNotDownloaded', () async {
    store.downloadGate = Completer<void>()
      ..completeError(const ModelNotDownloaded(TranslateLanguage.hindi));
    await expectLater(
      models.download(TranslateLanguage.hindi),
      throwsA(
        isA<ModelNotDownloaded>().having(
          (e) => e.language,
          'language',
          TranslateLanguage.hindi,
        ),
      ),
    );
  });

  test('deletes a model', () async {
    store.present.add(TranslateLanguage.hindi);
    await models.delete(TranslateLanguage.hindi);
    expect(await models.isDownloaded(TranslateLanguage.hindi), isFalse);
  });

  test('lists exactly the downloaded languages', () async {
    store.present.addAll({TranslateLanguage.english, TranslateLanguage.hindi});
    expect(await models.downloaded(), {
      TranslateLanguage.english,
      TranslateLanguage.hindi,
    });
    expect(store.checks.toSet(), TranslateLanguage.values.toSet());
  });
}
