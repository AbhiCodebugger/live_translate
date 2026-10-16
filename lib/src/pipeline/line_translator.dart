import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code, TranslateLanguage;

import '../cache/translation_cache.dart';
import '../engines/language_engine.dart';
import '../engines/line_filter.dart';
import '../engines/model_store.dart';
import '../engines/text_engine.dart';
import '../engines/translate_engine.dart';
import '../errors.dart';
import '../models/source_status.dart';
import '../models/text_script.dart';

/// The lowest confidence at which a language guess is trusted.
const minLanguageConfidence = 0.5;

/// The language [guesses] for a line that can be trusted: those at or above
/// [minLanguageConfidence], only for languages in [hint] when one is given,
/// most confident first. Undetermined guesses ("und") never qualify.
List<LanguageGuess> qualifyingGuesses(
  List<LanguageGuess> guesses,
  Set<TranslateLanguage>? hint,
) {
  final allowed = hint?.map((language) => language.bcpCode).toSet();
  return [
    for (final guess in guesses)
      if (guess.tag != 'und' &&
          guess.confidence >= minLanguageConfidence &&
          (allowed == null || allowed.contains(guess.tag)))
        guess,
  ]..sort((a, b) => b.confidence.compareTo(a.confidence));
}

const _devanagariLanguages = {
  TranslateLanguage.hindi,
  TranslateLanguage.marathi,
};

const _latinLanguages = {
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

/// The script [language] is written in, among the scripts the package reads,
/// or `null` for a language written in another script.
TextScript? scriptOf(TranslateLanguage language) {
  if (_devanagariLanguages.contains(language)) return TextScript.devanagari;
  if (_latinLanguages.contains(language)) return TextScript.latin;
  return null;
}

/// A recognized line with its detected language and translation.
@immutable
final class LineTranslation {
  /// Creates a line translation.
  const LineTranslation({
    required this.line,
    this.sourceLanguage,
    this.translatedText,
    this.missingModels = const {},
  });

  /// The recognized line.
  final RecognizedLine line;

  /// The line's language as a BCP-47 tag, or `null` if undetermined.
  final String? sourceLanguage;

  /// The translation, or `null` while it isn't available: the language is
  /// undetermined or unsupported, a model is still downloading, or
  /// translation failed.
  final String? translatedText;

  /// The models, source or target, that weren't ready for this line, so it
  /// was left untranslated. Empty when nothing was missing.
  final Set<TranslateLanguage> missingModels;

  @override
  bool operator ==(Object other) =>
      other is LineTranslation &&
      other.line == line &&
      other.sourceLanguage == sourceLanguage &&
      other.translatedText == translatedText &&
      setEquals(other.missingModels, missingModels);

  @override
  int get hashCode => Object.hash(
    line,
    sourceLanguage,
    translatedText,
    Object.hashAllUnordered(missingModels),
  );

  @override
  String toString() =>
      'LineTranslation(${line.text} [$sourceLanguage] -> $translatedText)';
}

/// What happened to an automatic model download.
enum ModelEvent {
  /// The download started.
  started,

  /// The model is on the device.
  ready,

  /// The download failed. A later confirmed line retries it.
  failed,
}

/// Where a language's translation model stands.
enum _ModelState { checking, available, missing, downloading }

/// Detects each line's language and translates it into the target language.
///
/// Never asks the translator to translate while a model is missing, because
/// ML Kit would then download it silently, unreported and unthrottled.
/// Instead, models download on any network:
///
/// - A missing target model is downloaded at once.
/// - A missing source model is downloaded once its language is confirmed:
///   assigned with confidence of at least [confirmConfidence] in
///   [confirmFrames] of the last [confirmWindow] frames. At most one such
///   download runs at a time.
/// - A missing model is checked again every [confirmWindow] frames, so a
///   model the app downloads is picked up.
///
/// Lines needing a missing model stay untranslated until it arrives. Each
/// download started is reported through `onError` once, and only for
/// confirmed languages, so a stray detection never reaches the app.
final class LineTranslator {
  /// Creates a line translator.
  LineTranslator({
    required LanguageEngine languageEngine,
    required TranslateEngine translateEngine,
    required ModelStore modelStore,
    required this._onError,
    TranslationCache? cache,
    this._onModelReady,
  }) : _languages = languageEngine,
       _translator = translateEngine,
       _models = modelStore,
       _cache = cache ?? TranslationCache();

  /// Each automatic download's start and end, as it happens.
  Stream<({TranslateLanguage language, ModelEvent event})> get modelEvents =>
      _modelEvents.stream;

  /// The confidence a detection needs to count towards confirmation.
  static const confirmConfidence = 0.8;

  /// How many frames must detect a language before it is downloaded.
  static const confirmFrames = 3;

  /// How many recent frames confirmation looks at.
  static const confirmWindow = 10;

  /// A text with at least this many letters, identified at
  /// [confirmConfidence] or more, confirms its language at once: long text
  /// is identified reliably, and reads can be seconds apart.
  static const confirmLetters = 20;

  final LanguageEngine _languages;
  final TranslateEngine _translator;
  final ModelStore _models;
  final void Function(LiveTranslateException error) _onError;
  final TranslationCache _cache;

  final _states = <TranslateLanguage, _ModelState>{};
  final _checks = <TranslateLanguage, Future<bool>>{};
  final _checkedAt = <TranslateLanguage, int>{};
  final _sightings = <String, List<int>>{};
  final _sightingScripts = <String, TextScript>{};
  final _reportedUnsupported = <String>{};
  final _confirmedAtOnce = <String>{};
  final _failed = <TranslateLanguage>{};
  final void Function(TranslateLanguage language)? _onModelReady;
  final _modelEvents =
      StreamController<
        ({TranslateLanguage language, ModelEvent event})
      >.broadcast(sync: true);
  int _frame = 0;
  bool _sourceDownloadRunning = false;

  /// Checks [target]'s model now, downloading it if it's missing, so it is
  /// ready before the first line arrives. Later checks share the result. A
  /// failed check is reported as a [PipelineFailure].
  void prepare(TranslateLanguage target) => unawaited(
    _ensureModel(target).then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) =>
          _onError(PipelineFailure(error, stackTrace)),
    ),
  );

  /// Translates [lines], the lines of one frame, into [target].
  ///
  /// Lines already in [target] are dropped. When [sourceLanguages] holds one
  /// language, every line written in that language's script is taken to be
  /// in it without identification; when it holds several, identification
  /// chooses among them. The lines of each script then share one language
  /// for the frame (see [_settle]).
  Future<List<LineTranslation>> translateLines(
    List<RecognizedLine> lines, {
    required TranslateLanguage target,
    Set<TranslateLanguage>? sourceLanguages,
  }) async => (await translateFrame(
    lines,
    target: target,
    sourceLanguages: sourceLanguages,
  )).lines;

  /// Translates [lines] as [translateLines] does, and also gives the
  /// frame's source status.
  ///
  /// The status names the language of the most lines not in [target], or
  /// [target] when every line with a language is in it. On a tie it keeps
  /// [current], a BCP-47 tag, when that is tied, and otherwise takes the
  /// first tied line's language. It is `null` when no line has a language.
  /// An untranslatable language is [SourceSearching] until it is
  /// confirmed, and [SourceUnsupported] after.
  Future<({List<LineTranslation> lines, SourceStatus? status})> translateFrame(
    List<RecognizedLine> lines, {
    required TranslateLanguage target,
    Set<TranslateLanguage>? sourceLanguages,
    String? current,
  }) async {
    final frame = ++_frame;
    final guesses = await Future.wait([
      for (final line in lines) _guess(line, sourceLanguages),
    ]);
    final sources = _settle(lines, guesses, target, frame);
    final results = await Future.wait([
      for (var i = 0; i < lines.length; i++)
        _translateLine(lines[i], sources[i], target),
    ]);
    return (
      lines: results.nonNulls.toList(),
      status: _statusOf(sources, target, current),
    );
  }

  SourceStatus? _statusOf(
    List<String?> sources,
    TranslateLanguage target,
    String? current,
  ) {
    final counts = <String, int>{};
    var inTarget = false;
    for (final source in sources) {
      if (source == null) continue;
      if (source == target.bcpCode) {
        inTarget = true;
        continue;
      }
      counts[source] = (counts[source] ?? 0) + 1;
    }
    if (counts.isEmpty) return inTarget ? SourceReady(target) : null;

    final most = counts.values.reduce(max);
    final named = counts[current] == most
        ? current!
        : counts.entries.firstWhere((entry) => entry.value == most).key;

    final language = BCP47Code.fromRawValue(named);
    if (language == null) {
      return _isConfirmed(named)
          ? SourceUnsupported(named)
          : const SourceSearching();
    }
    if (_failed.contains(language)) return SourceDownloadFailed(language);
    return switch (_states[language]) {
      _ModelState.available => SourceReady(language),
      _ModelState.downloading => SourceDownloading(language),
      _ => SourceGuessed(language),
    };
  }

  /// The qualifying language guesses for [line], most confident first.
  Future<List<LanguageGuess>> _guess(
    RecognizedLine line,
    Set<TranslateLanguage>? hint,
  ) async {
    if (hint != null && hint.length == 1) {
      // A single expected language is assigned without identification, but
      // only to lines written in its script: a Latin URL isn't Hindi.
      final script = scriptOf(hint.single);
      return script == null || hasLetterOf(line.text, script)
          ? [LanguageGuess(hint.single.bcpCode, 1)]
          : const [];
    }
    return qualifyingGuesses(await _languages.identify(line.text), hint);
  }

  /// Gives each line its source language for this [frame], recording the
  /// confident ones for confirmation.
  ///
  /// Lines are grouped by script, Devanagari before Latin, and each group
  /// takes the language with the highest total confidence across its lines,
  /// so one line misread as a related language (Hindi as Marathi) follows
  /// the others. A line whose own best guess is [target] keeps it, so it is
  /// still dropped, and doesn't vote. Lines in neither script keep their own
  /// best guess.
  List<String?> _settle(
    List<RecognizedLine> lines,
    List<List<LanguageGuess>> guesses,
    TranslateLanguage target,
    int frame,
  ) {
    final sources = List<String?>.filled(lines.length, null);
    final groups = <TextScript, List<int>>{};
    for (var i = 0; i < lines.length; i++) {
      if (guesses[i].isEmpty) continue;
      if (guesses[i].first.tag == target.bcpCode) {
        // Already in the target language: dropped, and left out of the vote.
        sources[i] = target.bcpCode;
        continue;
      }
      final script = [
        TextScript.devanagari,
        TextScript.latin,
      ].where((script) => hasLetterOf(lines[i].text, script)).firstOrNull;
      if (script == null) {
        final own = guesses[i].first;
        sources[i] = own.tag;
        if (own.confidence >= confirmConfidence) {
          _sight(own.tag, frame);
          if (_isLong(lines[i].text)) _confirmedAtOnce.add(own.tag);
        }
      } else {
        groups.putIfAbsent(script, () => []).add(i);
      }
    }

    for (final MapEntry(key: script, value: members) in groups.entries) {
      // Untranslatable guesses, such as lorem ipsum read as Latin, don't
      // vote when a translatable language is in the running: they would
      // carry the real paragraphs along with them.
      final translatableOnly = members.any(
        (i) => guesses[i].any((guess) => _isTranslatable(guess.tag)),
      );
      final totals = <String, double>{};
      for (final i in members) {
        for (final guess in guesses[i]) {
          if (translatableOnly && !_isTranslatable(guess.tag)) continue;
          totals[guess.tag] = (totals[guess.tag] ?? 0) + guess.confidence;
        }
      }
      final winner = totals.entries
          .reduce((best, next) => next.value > best.value ? next : best)
          .key;
      final support = <double>[];
      for (final i in members) {
        if (translatableOnly &&
            !guesses[i].any((guess) => _isTranslatable(guess.tag))) {
          // Only untranslatable guesses: the line keeps its own.
          final own = guesses[i].first;
          sources[i] = own.tag;
          if (own.confidence >= confirmConfidence) {
            _sight(own.tag, frame);
            if (_isLong(lines[i].text)) _confirmedAtOnce.add(own.tag);
          }
          continue;
        }
        sources[i] = winner;
        for (final guess in guesses[i]) {
          if (guess.tag != winner) continue;
          support.add(guess.confidence);
          if (guess.confidence >= confirmConfidence && _isLong(lines[i].text)) {
            _confirmedAtOnce.add(winner);
          }
        }
      }
      final average = support.reduce((a, b) => a + b) / support.length;
      if (average >= confirmConfidence) {
        _sight(winner, frame, script: script);
      }
    }
    return sources;
  }

  Future<LineTranslation?> _translateLine(
    RecognizedLine line,
    String? source,
    TranslateLanguage target,
  ) async {
    if (source == null) return LineTranslation(line: line);
    if (source == target.bcpCode) return null;

    final from = BCP47Code.fromRawValue(source);
    if (from == null) {
      if (_isConfirmed(source) && _reportedUnsupported.add(source)) {
        _onError(UnsupportedLanguagePair(source: source, target: target));
      }
      return LineTranslation(line: line, sourceLanguage: source);
    }

    final [sourceReady, targetReady] = await Future.wait([
      _ensureModel(from, isSource: true),
      _ensureModel(target),
    ]);
    if (!sourceReady || !targetReady) {
      return LineTranslation(
        line: line,
        sourceLanguage: source,
        missingModels: {if (!sourceReady) from, if (!targetReady) target},
      );
    }

    final cached = _cache.get(line.text, from: from, to: target);
    if (cached != null) {
      return LineTranslation(
        line: line,
        sourceLanguage: source,
        translatedText: cached,
      );
    }
    try {
      final translated = await _translator.translate(
        line.text,
        from: from,
        to: target,
      );
      _cache.put(line.text, translated, from: from, to: target);
      return LineTranslation(
        line: line,
        sourceLanguage: source,
        translatedText: translated,
      );
    } catch (error, stackTrace) {
      _onError(PipelineFailure(error, stackTrace));
      return LineTranslation(line: line, sourceLanguage: source);
    }
  }

  /// Records that the language [tag] was detected confidently in [frame],
  /// as the language of [script] when it won one.
  void _sight(String tag, int frame, {TextScript? script}) {
    final frames = _sightings.putIfAbsent(tag, () => []);
    if (frames.isEmpty || frames.last != frame) frames.add(frame);
    frames.removeWhere((f) => f <= frame - confirmWindow);
    if (script != null) _sightingScripts[tag] = script;
  }

  int _recentSightings(String tag) =>
      _sightings[tag]?.where((f) => f > _frame - confirmWindow).length ?? 0;

  /// Whether [tag] was sighted in [confirmFrames] of the last
  /// [confirmWindow] frames, and more often than any other language of its
  /// script.
  bool _isConfirmed(String tag) {
    if (_confirmedAtOnce.contains(tag)) return true;
    final count = _recentSightings(tag);
    if (count < confirmFrames) return false;
    final script = _sightingScripts[tag];
    if (script == null) return true;
    // A translatable language doesn't compete with untranslatable ones,
    // which no longer win its script's vote.
    final translatable = _isTranslatable(tag);
    return _sightingScripts.entries.every(
      (other) =>
          other.key == tag ||
          other.value != script ||
          (translatable && !_isTranslatable(other.key)) ||
          _recentSightings(other.key) < count,
    );
  }

  /// Whether [language]'s model is ready. A missing model may start a
  /// download: at once for the target, and only once confirmed for a source
  /// ([isSource]).
  Future<bool> _ensureModel(
    TranslateLanguage language, {
    bool isSource = false,
  }) async {
    switch (_states[language]) {
      case _ModelState.available:
        return true;
      case _ModelState.downloading:
        return false;
      case _ModelState.missing
          when _frame - (_checkedAt[language] ?? 0) < confirmWindow:
        _onMissing(language, isSource: isSource);
        return false;
      case _ModelState.missing || _ModelState.checking || null:
        // Lines asking at the same time share one check. The callback must
        // not return the removed future: whenComplete would then wait on
        // itself.
        _states[language] = _ModelState.checking;
        _checkedAt[language] = _frame;
        final present = await (_checks[language] ??= _models
            .isDownloaded(language)
            .whenComplete(() {
              _checks.remove(language);
            }));
        if (present) {
          _states[language] = _ModelState.available;
          _failed.remove(language);
          return true;
        }
        if (_states[language] == _ModelState.checking) {
          _states[language] = _ModelState.missing;
        }
        _onMissing(language, isSource: isSource);
        return false;
    }
  }

  void _onMissing(TranslateLanguage language, {required bool isSource}) {
    if (_states[language] != _ModelState.missing) return;
    if (isSource) {
      if (!_isConfirmed(language.bcpCode)) return;
      if (_sourceDownloadRunning) return;
      _sourceDownloadRunning = true;
    }
    _states[language] = _ModelState.downloading;
    _failed.remove(language);
    _onError(ModelNotDownloaded(language));
    _modelEvents.add((language: language, event: ModelEvent.started));
    unawaited(
      _models
          .download(language, wifiOnly: false)
          .then<void>(
            (_) {
              _states[language] = _ModelState.available;
              _onModelReady?.call(language);
              _modelEvents.add((language: language, event: ModelEvent.ready));
            },
            // A later confirmed line retries; the failure was already
            // reported as the missing model.
            onError: (Object _) {
              _states[language] = _ModelState.missing;
              _failed.add(language);
              _modelEvents.add((language: language, event: ModelEvent.failed));
            },
          )
          .whenComplete(() {
            if (isSource) _sourceDownloadRunning = false;
          }),
    );
  }
}

final _letter = RegExp(r'\p{L}', unicode: true);

/// Whether [text] has at least [LineTranslator.confirmLetters] letters.
bool _isLong(String text) =>
    _letter.allMatches(text).take(LineTranslator.confirmLetters).length ==
    LineTranslator.confirmLetters;

/// Whether [tag] is a language with an on-device translation model.
bool _isTranslatable(String tag) => BCP47Code.fromRawValue(tag) != null;
