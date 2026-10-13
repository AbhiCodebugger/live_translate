import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/engines/line_filter.dart';
import 'package:live_translate/src/models/text_script.dart';

void main() {
  group('hasEnoughLettersOf Latin', () {
    for (final text in ['2026', 'A', '!!', '', '  ', '12:30', 'नमस्ते']) {
      test(
        'drops "$text"',
        () => expect(hasEnoughLettersOf(text, TextScript.latin), isFalse),
      );
    }

    for (final text in ['Platform 2', 'No entry', 'Ok']) {
      test(
        'keeps "$text"',
        () => expect(hasEnoughLettersOf(text, TextScript.latin), isTrue),
      );
    }
  });

  group('hasEnoughLettersOf Devanagari', () {
    for (final text in ['नमस्ते', 'दवा 500mg']) {
      test(
        'keeps "$text"',
        () => expect(hasEnoughLettersOf(text, TextScript.devanagari), isTrue),
      );
    }

    for (final text in ['Elememte chan na', 'Lorem क ipsum', '2026']) {
      test(
        'drops "$text"',
        () => expect(hasEnoughLettersOf(text, TextScript.devanagari), isFalse),
      );
    }

    test('counts vowel signs as marks, not letters', () {
      expect(hasEnoughLettersOf('है', TextScript.devanagari), isFalse);
      // A vowel sign after a Latin letter doesn't make a Devanagari letter.
      expect(
        hasEnoughLettersOf('Lorem ा ipsum ी', TextScript.devanagari),
        isFalse,
      );
    });
  });

  test('hasLetterOf finds letters of a script', () {
    expect(hasLetterOf('नमस्ते', TextScript.devanagari), isTrue);
    expect(hasLetterOf('दवा 500mg', TextScript.devanagari), isTrue);
    expect(
      hasLetterOf('en.wikipedia.org/wiki', TextScript.devanagari),
      isFalse,
    );
    expect(hasLetterOf('en.wikipedia.org/wiki', TextScript.latin), isTrue);
    expect(hasLetterOf('नमस्ते', TextScript.latin), isFalse);
    expect(hasLetterOf('2026 !!', TextScript.latin), isFalse);
  });
}
