import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/cache/translation_cache.dart';

void main() {
  const es = TranslateLanguage.spanish;
  const en = TranslateLanguage.english;
  const fr = TranslateLanguage.french;

  late TranslationCache cache;

  setUp(() => cache = TranslationCache());

  test('normalizes line text', () {
    expect(
      normalizeLineText('  Salida \n de   emergencia '),
      'Salida de emergencia',
    );
  });

  test('returns a stored translation', () {
    cache.put('Salida', 'Exit', from: es, to: en);
    expect(cache.get('Salida', from: es, to: en), 'Exit');
  });

  test('misses unknown text', () {
    expect(cache.get('Salida', from: es, to: en), isNull);
  });

  test('ignores leading, trailing and repeated whitespace', () {
    cache.put(' Salida  de emergencia', 'Emergency exit', from: es, to: en);
    expect(
      cache.get('Salida de emergencia', from: es, to: en),
      'Emergency exit',
    );
    expect(cache.length, 1);
  });

  test('keeps language pairs apart', () {
    cache.put('Salida', 'Exit', from: es, to: en);
    expect(cache.get('Salida', from: es, to: fr), isNull);
  });

  test('holds 200 entries by default and evicts the oldest', () {
    for (var i = 0; i < 201; i++) {
      cache.put('text $i', 'translation $i', from: es, to: en);
    }
    expect(cache.length, 200);
    expect(cache.get('text 0', from: es, to: en), isNull);
    expect(cache.get('text 1', from: es, to: en), 'translation 1');
  });

  test('reading an entry protects it from eviction', () {
    final small = TranslationCache(capacity: 2)
      ..put('a', 'A', from: es, to: en)
      ..put('b', 'B', from: es, to: en);
    small
      ..get('a', from: es, to: en)
      ..put('c', 'C', from: es, to: en);
    expect(small.get('a', from: es, to: en), 'A');
    expect(small.get('b', from: es, to: en), isNull);
  });

  test('putting the same text again updates it without growing', () {
    cache
      ..put('Salida', 'Exit', from: es, to: en)
      ..put('Salida', 'Way out', from: es, to: en);
    expect(cache.get('Salida', from: es, to: en), 'Way out');
    expect(cache.length, 1);
  });
}
