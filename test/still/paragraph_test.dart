import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/still/paragraph.dart';

void main() {
  test('joins lines with a space', () {
    expect(
      joinParagraph([
        'On sait depuis longtemps que travailler',
        'avec du texte lisible',
      ]),
      'On sait depuis longtemps que travailler avec du texte lisible',
    );
  });

  test('rejoins a word hyphenated at a line end', () {
    expect(
      joinParagraph(['une distri-', 'bution normale']),
      'une distribution normale',
    );
  });

  test('keeps a dash that follows a space', () {
    expect(joinParagraph(['texte -', 'suite']), 'texte - suite');
  });

  test('trims surrounding whitespace and skips blank lines', () {
    expect(
      joinParagraph(['  Bonjour ', '   ', ' le monde  ']),
      'Bonjour le monde',
    );
  });

  test('a single line comes back unchanged', () {
    expect(joinParagraph(['Pourquoi l’utiliser ?']), 'Pourquoi l’utiliser ?');
  });

  test('a hyphen on the last line is kept', () {
    expect(joinParagraph(['Lorem', 'Ipsum-']), 'Lorem Ipsum-');
  });
}
