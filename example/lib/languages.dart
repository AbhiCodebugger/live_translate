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

/// What the source chip reads for [status] while detecting.
String sourceStatusLabel(SourceStatus status) => switch (status) {
  SourceSearching() => 'Looking for text…',
  SourceGuessed(:final language) => '${displayName(language)}?',
  SourceDownloading(:final language) ||
  SourceReady(:final language) => displayName(language),
  SourceUnsupported(:final tag) => "${tagName(tag)} can't be translated",
  SourceNotFound() => 'No supported text found',
  SourceDownloadFailed(:final language) =>
    '${displayName(language)} · download failed',
};

/// The English name of the language [tag], or [tag] itself when it isn't
/// known: a translatable language, or one ML Kit identifies but can't
/// translate.
String tagName(String tag) => switch (BCP47Code.fromRawValue(tag)) {
  final language? => displayName(language),
  null => untranslatableNames[tag] ?? tag,
};

/// Names of languages ML Kit's language identification reports but its
/// translation doesn't cover.
const untranslatableNames = {
  'am': 'Amharic',
  'ar-Latn': 'Arabic (Latin script)',
  'bg-Latn': 'Bulgarian (Latin script)',
  'co': 'Corsican',
  'el-Latn': 'Greek (Latin script)',
  'fy': 'Frisian',
  'ha': 'Hausa',
  'haw': 'Hawaiian',
  'hi-Latn': 'Hindi (Latin script)',
  'hmn': 'Hmong',
  'ig': 'Igbo',
  'ja-Latn': 'Japanese (Latin script)',
  'km': 'Khmer',
  'ku': 'Kurdish',
  'ky': 'Kyrgyz',
  'la': 'Latin',
  'lb': 'Luxembourgish',
  'lo': 'Lao',
  'mi': 'Maori',
  'mn': 'Mongolian',
  'my': 'Burmese',
  'ne': 'Nepali',
  'ny': 'Chichewa',
  'ps': 'Pashto',
  'ru-Latn': 'Russian (Latin script)',
  'sd': 'Sindhi',
  'si': 'Sinhala',
  'sm': 'Samoan',
  'sn': 'Shona',
  'so': 'Somali',
  'st': 'Sesotho',
  'su': 'Sundanese',
  'tg': 'Tajik',
  'uz': 'Uzbek',
  'xh': 'Xhosa',
  'yi': 'Yiddish',
  'yo': 'Yoruba',
  'zh-Latn': 'Chinese (Latin script)',
  'zu': 'Zulu',
};
