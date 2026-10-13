import 'dart:ui' show Locale;

import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code, TranslateLanguage;

/// The language to translate into when the app doesn't choose one: the
/// device's [locale] language, or English when it has no on-device model.
///
/// Only the language code counts, so `en_US` and `en_GB` are both English.
TranslateLanguage deviceTargetLanguage(Locale locale) =>
    BCP47Code.fromRawValue(locale.languageCode) ?? TranslateLanguage.english;
