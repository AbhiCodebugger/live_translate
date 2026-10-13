import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/models/text_script.dart';
import 'package:live_translate/src/pipeline/line_translator.dart';

void main() {
  test('scriptOf knows the scripts the package reads', () {
    expect(scriptOf(TranslateLanguage.hindi), TextScript.devanagari);
    expect(scriptOf(TranslateLanguage.marathi), TextScript.devanagari);
    expect(scriptOf(TranslateLanguage.spanish), TextScript.latin);
    expect(scriptOf(TranslateLanguage.english), TextScript.latin);
    expect(scriptOf(TranslateLanguage.arabic), isNull);
    expect(scriptOf(TranslateLanguage.chinese), isNull);
  });
}
