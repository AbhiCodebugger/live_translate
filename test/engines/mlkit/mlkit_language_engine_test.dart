import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:live_translate/src/engines/language_engine.dart';
import 'package:live_translate/src/engines/mlkit/mlkit_language_engine.dart';

final class _FakeIdentifier implements LanguageIdentifier {
  _FakeIdentifier(this.candidates);

  final List<IdentifiedLanguage> candidates;
  int closes = 0;

  @override
  double get confidenceThreshold => MlKitLanguageEngine.candidateThreshold;

  @override
  String get undeterminedLanguageCode => 'und';

  @override
  String get id => 'fake';

  @override
  Future<String> identifyLanguage(String text) async =>
      candidates.first.languageTag;

  @override
  Future<List<IdentifiedLanguage>> identifyPossibleLanguages(
    String text,
  ) async => candidates;

  @override
  Future<void> close() async => closes++;
}

void main() {
  late List<_FakeIdentifier> created;

  MlKitLanguageEngine engine(List<IdentifiedLanguage> candidates) {
    created = [];
    return MlKitLanguageEngine(
      createIdentifier: () {
        final identifier = _FakeIdentifier(candidates);
        created.add(identifier);
        return identifier;
      },
    );
  }

  final candidates = [
    IdentifiedLanguage(languageTag: 'mr', confidence: 0.3),
    IdentifiedLanguage(languageTag: 'hi', confidence: 0.55),
  ];

  test('creates no identifier until first use', () async {
    final e = engine(candidates);
    await e.close();
    expect(created, isEmpty);
  });

  test('maps candidates to guesses, most likely first', () async {
    final guesses = await engine(candidates).identify('नमस्ते');
    expect(guesses, const [
      LanguageGuess('hi', 0.55),
      LanguageGuess('mr', 0.3),
    ]);
  });

  test('reuses one identifier and closes it exactly once', () async {
    final e = engine(candidates);
    await e.identify('a');
    await e.identify('b');
    await e.close();
    await e.close();
    expect(created, hasLength(1));
    expect(created.single.closes, 1);
  });

  test('throws when used after close', () async {
    final e = engine(candidates);
    await e.close();
    await expectLater(e.identify('a'), throwsStateError);
  });
}
