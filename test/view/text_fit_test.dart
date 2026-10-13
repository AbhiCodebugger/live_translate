import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/view/text_fit.dart';

void main() {
  test('right-to-left languages', () {
    for (final language in [
      TranslateLanguage.arabic,
      TranslateLanguage.hebrew,
      TranslateLanguage.persian,
      TranslateLanguage.urdu,
    ]) {
      expect(
        textDirectionFor(language),
        TextDirection.rtl,
        reason: '$language',
      );
    }
    expect(textDirectionFor(TranslateLanguage.english), TextDirection.ltr);
    expect(textDirectionFor(TranslateLanguage.hindi), TextDirection.ltr);
  });
}
