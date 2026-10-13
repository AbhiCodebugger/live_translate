import 'dart:ui' show Color, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/still/read_result.dart';

ReadParagraph _paragraph({
  String translatedText = 'Exit',
  List<Rect> lineBoxes = const [Rect.fromLTRB(10, 10, 90, 30)],
  String? sourceLanguage = 'es',
  Color? ink = const Color(0xFF000000),
}) => ReadParagraph(
  box: const Rect.fromLTRB(10, 10, 90, 30),
  lineBoxes: lineBoxes,
  sourceText: 'Salida',
  sourceLanguage: sourceLanguage,
  translatedText: translatedText,
  background: const Color(0xFFFFFFFF),
  ink: ink,
);

void main() {
  test('paragraphs with equal fields are equal', () {
    // Separate list instances: equality compares their contents.
    expect(
      _paragraph(lineBoxes: [const Rect.fromLTRB(10, 10, 90, 30)]),
      _paragraph(),
    );
    expect(_paragraph().hashCode, _paragraph().hashCode);
  });

  test('any differing field breaks equality', () {
    expect(_paragraph(translatedText: 'Way out'), isNot(_paragraph()));
    expect(
      _paragraph(lineBoxes: const [Rect.fromLTRB(10, 10, 90, 31)]),
      isNot(_paragraph()),
    );
    expect(_paragraph(sourceLanguage: null), isNot(_paragraph()));
    expect(_paragraph(ink: null), isNot(_paragraph()));
  });

  test('toString names the source, language and translation', () {
    expect(
      _paragraph().toString(),
      allOf(contains('"Salida"'), contains('[es]'), contains('"Exit"')),
    );
  });
}
