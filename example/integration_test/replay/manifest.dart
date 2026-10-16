import 'dart:convert';

// The package exports TranslateLanguage but not its BCP-47 lookup.
// ignore: depend_on_referenced_packages
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code;
import 'package:live_translate/live_translate.dart';

/// One paragraph a correct read of a frame must contain.
final class Expectation {
  /// Creates an expectation.
  const Expectation({
    required this.source,
    required this.language,
    this.translation = const [],
  });

  /// A fragment of the paragraph's recognised text.
  final String source;

  /// The paragraph's detected language, as a BCP-47 code.
  final String language;

  /// Keywords, any one of which the translation must contain; empty to
  /// accept any translation.
  final List<String> translation;

  @override
  String toString() =>
      '"$source" [$language]'
      '${translation.isEmpty ? '' : ' → any of $translation'}';
}

/// One replay frame and what reading it must find.
final class ReplayFrameSpec {
  /// Creates a frame description.
  const ReplayFrameSpec({
    required this.file,
    required this.target,
    required this.scripts,
    required this.expect,
    this.sourceLanguages,
    this.note = '',
  });

  /// The photo's file name in the frame folder.
  final String file;

  /// What the photo shows, for people reading failures.
  final String note;

  /// The language to translate into.
  final TranslateLanguage target;

  /// The scripts to read.
  final Set<TextScript> scripts;

  /// The expected source languages, or `null` to detect them.
  final Set<TranslateLanguage>? sourceLanguages;

  /// The paragraphs a correct read contains.
  final List<Expectation> expect;
}

/// The replay frames and their expectations, from `frames.json`.
final class ReplayManifest {
  const ReplayManifest._(this.frames);

  /// Parses the manifest [json]. Throws a [FormatException] naming the
  /// frame and field at fault.
  factory ReplayManifest.parse(String json) {
    final root = jsonDecode(json);
    if (root is! Map<String, Object?> || root['frames'] is! List<Object?>) {
      throw const FormatException('frames.json needs a "frames" list');
    }
    return ReplayManifest._([
      for (final (i, entry) in (root['frames']! as List<Object?>).indexed)
        _frame(entry, i),
    ]);
  }

  /// Every frame, in manifest order.
  final List<ReplayFrameSpec> frames;

  /// Every language whose translation model the frames need.
  Set<TranslateLanguage> get languages => {
    for (final frame in frames) ...{
      frame.target,
      for (final expectation in frame.expect)
        ?_languageOrNull(expectation.language),
    },
  };

  static ReplayFrameSpec _frame(Object? entry, int index) {
    if (entry is! Map<String, Object?>) {
      throw FormatException('frame $index is not an object');
    }
    final file = entry['file'];
    if (file is! String || file.isEmpty) {
      throw FormatException('frame $index has no "file"');
    }
    Never fail(String problem) => throw FormatException('$file: $problem');

    TranslateLanguage language(Object? code, String field) => code is String
        ? _languageOrNull(code) ?? fail('unknown language "$code" in $field')
        : fail('$field must be a language code');

    final scripts = entry['scripts'];
    if (scripts is! List<Object?> || scripts.isEmpty) {
      fail('"scripts" must list latin and/or devanagari');
    }
    final sources = entry['sourceLanguages'];
    final expect = entry['expect'];
    if (expect is! List<Object?> || expect.isEmpty) {
      fail('"expect" must list at least one paragraph');
    }
    return ReplayFrameSpec(
      file: file,
      note: entry['note'] is String ? entry['note']! as String : '',
      target: language(entry['target'], 'target'),
      scripts: {
        for (final name in scripts)
          TextScript.values.firstWhere(
            (s) => s.name == name,
            orElse: () => fail('unknown script "$name"'),
          ),
      },
      sourceLanguages: switch (sources) {
        null => null,
        final List<Object?> codes => {
          for (final code in codes) language(code, 'sourceLanguages'),
        },
        _ => fail('"sourceLanguages" must be null or a list'),
      },
      expect: [
        for (final item in expect)
          if (item case {
            'source': final String source,
            'language': final String code,
          })
            Expectation(
              source: source,
              language: language(code, 'expect').bcpCode,
              translation: [
                for (final word in item['translation'] as List<Object?>? ?? [])
                  if (word is String) word,
              ],
            )
          else
            fail('each "expect" entry needs "source" and "language"'),
      ],
    );
  }

  static TranslateLanguage? _languageOrNull(String code) {
    for (final language in TranslateLanguage.values) {
      if (language.bcpCode == code) return language;
    }
    return null;
  }
}
