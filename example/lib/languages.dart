// The package exports TranslateLanguage but not its BCP-47 lookup, and pins
// the version of the plugin that defines it.
// ignore: depend_on_referenced_packages
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code;
import 'package:live_translate/live_translate.dart';

/// The languages ML Kit translates that are written in Devanagari.
const devanagariLanguages = {
  TranslateLanguage.hindi,
  TranslateLanguage.marathi,
};

/// The languages ML Kit translates that are written in Latin script.
const latinLanguages = {
  TranslateLanguage.afrikaans,
  TranslateLanguage.albanian,
  TranslateLanguage.catalan,
  TranslateLanguage.croatian,
  TranslateLanguage.czech,
  TranslateLanguage.danish,
  TranslateLanguage.dutch,
  TranslateLanguage.english,
  TranslateLanguage.esperanto,
  TranslateLanguage.estonian,
  TranslateLanguage.finnish,
  TranslateLanguage.french,
  TranslateLanguage.galician,
  TranslateLanguage.german,
  TranslateLanguage.haitian,
  TranslateLanguage.hungarian,
  TranslateLanguage.icelandic,
  TranslateLanguage.indonesian,
  TranslateLanguage.irish,
  TranslateLanguage.italian,
  TranslateLanguage.latvian,
  TranslateLanguage.lithuanian,
  TranslateLanguage.malay,
  TranslateLanguage.maltese,
  TranslateLanguage.norwegian,
  TranslateLanguage.polish,
  TranslateLanguage.portuguese,
  TranslateLanguage.romanian,
  TranslateLanguage.slovak,
  TranslateLanguage.slovenian,
  TranslateLanguage.spanish,
  TranslateLanguage.swahili,
  TranslateLanguage.swedish,
  TranslateLanguage.tagalog,
  TranslateLanguage.turkish,
  TranslateLanguage.vietnamese,
  TranslateLanguage.welsh,
};

/// The languages written in scripts the example doesn't read, so they can't
/// be chosen as a source. Kept so a new ML Kit language fails the tests
/// until it is placed in one of the three sets.
const otherScriptLanguages = {
  TranslateLanguage.arabic,
  TranslateLanguage.belarusian,
  TranslateLanguage.bengali,
  TranslateLanguage.bulgarian,
  TranslateLanguage.chinese,
  TranslateLanguage.georgian,
  TranslateLanguage.greek,
  TranslateLanguage.gujarati,
  TranslateLanguage.hebrew,
  TranslateLanguage.japanese,
  TranslateLanguage.kannada,
  TranslateLanguage.korean,
  TranslateLanguage.macedonian,
  TranslateLanguage.persian,
  TranslateLanguage.russian,
  TranslateLanguage.tamil,
  TranslateLanguage.telugu,
  TranslateLanguage.thai,
  TranslateLanguage.ukrainian,
  TranslateLanguage.urdu,
};

/// The source picker's choices: `null` for "Detect language", then every
/// language the example can read.
final List<TranslateLanguage?> sourceOptions = [
  null,
  ...devanagariLanguages,
  ...latinLanguages,
];

/// What a source choice displays as: "Detect language" for `null`.
String sourceName(TranslateLanguage? source) =>
    source == null ? 'Detect language' : displayName(source);

/// The English name of [language].
String displayName(TranslateLanguage language) => switch (language) {
  TranslateLanguage.haitian => 'Haitian Creole',
  _ => language.name[0].toUpperCase() + language.name.substring(1),
};

/// The source languages and scripts the view reads for a [source] choice,
/// where `null` means "Detect language".
({Set<TranslateLanguage>? sourceLanguages, Set<TextScript> scripts}) readingFor(
  TranslateLanguage? source,
) => switch (source) {
  null => (
    sourceLanguages: null,
    scripts: const {TextScript.latin, TextScript.devanagari},
  ),
  _ when devanagariLanguages.contains(source) => (
    sourceLanguages: {source},
    scripts: const {TextScript.devanagari},
  ),
  _ => (sourceLanguages: {source}, scripts: const {TextScript.latin}),
};

/// The language most of [lines] were translated from, or `null` when none
/// has a known source language.
///
/// On a tie, [current] wins if it is among the tied, so the label doesn't
/// flicker between equally common languages; otherwise the first tied
/// language in line order does.
TranslateLanguage? detectedLanguage(
  List<TranslatedLine> lines,
  TranslateLanguage? current,
) {
  final counts = <TranslateLanguage, int>{};
  for (final line in lines) {
    final language = switch (line.sourceLanguage) {
      final tag? => BCP47Code.fromRawValue(tag),
      null => null,
    };
    if (language != null) counts[language] = (counts[language] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final most = counts.values.reduce((a, b) => a > b ? a : b);
  if (counts[current] == most) return current;
  return counts.entries.firstWhere((entry) => entry.value == most).key;
}
