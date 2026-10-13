import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/models/device_language.dart';

void main() {
  test('English in any region is English', () {
    expect(
      deviceTargetLanguage(const Locale('en', 'US')),
      TranslateLanguage.english,
    );
    expect(
      deviceTargetLanguage(const Locale('en', 'GB')),
      TranslateLanguage.english,
    );
  });

  test('French is French', () {
    expect(
      deviceTargetLanguage(const Locale('fr', 'FR')),
      TranslateLanguage.french,
    );
  });

  test('Hindi is Hindi', () {
    expect(
      deviceTargetLanguage(const Locale('hi', 'IN')),
      TranslateLanguage.hindi,
    );
  });

  test('a language without an on-device model falls back to English', () {
    expect(
      deviceTargetLanguage(const Locale('am', 'ET')),
      TranslateLanguage.english,
    );
  });
}
