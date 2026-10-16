import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/models/translated_paragraph.dart';

void main() {
  const rect = Rect.fromLTWH(10, 20, 100, 30);

  TranslatedParagraph line({
    double opacity = 1.0,
    String? sourceLanguage = 'hi',
  }) => TranslatedParagraph(
    id: 'line-1',
    sourceText: 'नमस्ते',
    translatedText: 'Hello',
    sourceLanguage: sourceLanguage,
    rect: rect,
    opacity: opacity,
  );

  group('TranslatedParagraph', () {
    test('is equal when all fields are equal', () {
      expect(line(), line());
      expect(line().hashCode, line().hashCode);
    });

    test('is not equal when only opacity differs', () {
      expect(line(opacity: 0.5), isNot(line()));
    });

    test('defaults to full opacity and an undetermined language', () {
      const minimal = TranslatedParagraph(
        id: 'line-1',
        sourceText: 'Hola',
        translatedText: 'Hello',
        rect: rect,
      );
      expect(minimal.opacity, 1.0);
      expect(minimal.sourceLanguage, isNull);
    });

    test('rejects opacity outside 0..1', () {
      expect(() => line(opacity: 1.5), throwsAssertionError);
      expect(() => line(opacity: -0.1), throwsAssertionError);
    });

    test('accepts the opacity bounds', () {
      expect(line(opacity: 0.0).opacity, 0.0);
      expect(line(opacity: 1.0).opacity, 1.0);
    });
  });
}
