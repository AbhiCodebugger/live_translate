import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:live_translate/src/engines/mlkit/mlkit_translate_engine.dart';

final class _FakeTranslator implements OnDeviceTranslator {
  _FakeTranslator(this.sourceLanguage, this.targetLanguage);

  @override
  final TranslateLanguage sourceLanguage;

  @override
  final TranslateLanguage targetLanguage;

  @override
  String get id => 'fake';

  final texts = <String>[];
  int closes = 0;

  @override
  Future<String> translateText(String text) async {
    texts.add(text);
    return '${sourceLanguage.name}->${targetLanguage.name}: $text';
  }

  @override
  Future<void> close() async => closes++;
}

void main() {
  late List<_FakeTranslator> created;
  late MlKitTranslateEngine engine;

  setUp(() {
    created = [];
    engine = MlKitTranslateEngine(
      createTranslator: (from, to) {
        final translator = _FakeTranslator(from, to);
        created.add(translator);
        return translator;
      },
    );
  });

  const es = TranslateLanguage.spanish;
  const fr = TranslateLanguage.french;
  const en = TranslateLanguage.english;

  test('creates one translator per language pair', () async {
    await engine.translate('Salida', from: es, to: en);
    await engine.translate('Entrada', from: es, to: en);
    await engine.translate('Sortie', from: fr, to: en);
    await engine.translate('Entrée', from: fr, to: en);

    expect(created, hasLength(2));
    expect(created[0].texts, ['Salida', 'Entrada']);
    expect(created[1].texts, ['Sortie', 'Entrée']);
  });

  test('returns the translator output', () async {
    expect(
      await engine.translate('Salida', from: es, to: en),
      'spanish->english: Salida',
    );
  });

  test('closes every translator once', () async {
    await engine.translate('Salida', from: es, to: en);
    await engine.translate('Sortie', from: fr, to: en);
    await engine.close();
    await engine.close();
    expect(created.map((t) => t.closes), [1, 1]);
  });

  test('creates nothing if never used', () async {
    await engine.close();
    expect(created, isEmpty);
  });

  test('throws when used after close', () async {
    await engine.close();
    await expectLater(
      engine.translate('Salida', from: es, to: en),
      throwsStateError,
    );
  });
}
