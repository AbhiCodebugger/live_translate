import 'package:flutter/painting.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;

const _rightToLeft = {
  TranslateLanguage.arabic,
  TranslateLanguage.hebrew,
  TranslateLanguage.persian,
  TranslateLanguage.urdu,
};

/// The direction text in [language] is written in.
TextDirection textDirectionFor(TranslateLanguage language) =>
    _rightToLeft.contains(language) ? TextDirection.rtl : TextDirection.ltr;
