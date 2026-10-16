import 'dart:async';
import 'dart:ui' show Rect;

import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code, TranslateLanguage;

import '../camera/camera_frame.dart';
import '../camera/input_image_converter.dart';
import '../engines/text_engine.dart';
import '../errors.dart';
import '../still/colour_sampler.dart';
import '../still/paragraph.dart';
import '../still/read_result.dart';
import 'line_translator.dart';

/// Reads camera frames: recognizes their text with every script, groups it
/// into paragraphs, translates each paragraph and samples its colours.
final class Pipeline {
  /// Creates a pipeline that recognizes text with `textEngine` and translates
  /// it into [target]. The target's model is checked, and downloaded if
  /// missing, straight away.
  ///
  /// Stages are timed with [now], the system clock by default.
  ///
  /// [createTranslator] builds the line translator; it receives the
  /// pipeline's error reporter, so translation problems reach [errors], and
  /// its model-ready reporter, which feeds [modelsReady].
  Pipeline({
    required TextEngine textEngine,
    required LineTranslator Function(
      void Function(LiveTranslateException error) onError,
      void Function(TranslateLanguage language) onModelReady,
    )
    createTranslator,
    required this.target,
    this.sourceLanguages,
    DateTime Function()? now,
  }) : _engine = textEngine,
       _now = now ?? DateTime.now {
    _translator = createTranslator(_report, _modelReady)..prepare(target);
    _translatorEvents = _translator.modelEvents.listen((event) {
      if (!_disposed) _modelEvents.add(event);
    });
  }

  /// The language text is translated into.
  final TranslateLanguage target;

  /// The expected source languages, or `null` to detect them.
  final Set<TranslateLanguage>? sourceLanguages;

  final TextEngine _engine;
  final DateTime Function() _now;
  late final LineTranslator _translator;
  final _errors = StreamController<LiveTranslateException>.broadcast();
  final _modelsReady = StreamController<TranslateLanguage>.broadcast();
  final _modelEvents =
      StreamController<
        ({TranslateLanguage language, ModelEvent event})
      >.broadcast();
  late final StreamSubscription<void> _translatorEvents;
  bool _disposed = false;

  /// Problems found while translating, such as a model starting to
  /// download. Failures of a read itself are thrown by [read] instead.
  Stream<LiveTranslateException> get errors => _errors.stream;

  /// Languages whose model the pipeline finished downloading.
  Stream<TranslateLanguage> get modelsReady => _modelsReady.stream;

  /// Each automatic model download's start, completion and failure.
  Stream<({TranslateLanguage language, ModelEvent event})> get modelEvents =>
      _modelEvents.stream;

  /// Reads [frame] with every script and translates it paragraph by
  /// paragraph, sampling each paragraph's page colours.
  ///
  /// Failures are thrown rather than reported. Returns `null` for a frame in
  /// an unsupported format.
  ///
  /// [currentSource], the BCP-47 tag the source status names now, breaks a
  /// tie between languages in the result's [ReadResult.sourceStatus].
  Future<ReadResult?> read(CameraFrame frame, {String? currentSource}) async {
    final start = _now();
    final input = toInputImage(frame.image, frame.rotation);
    if (input == null) return null;
    final lines = await _engine.recognize(input);
    final recognized = _now();

    final byParagraph = <int, List<RecognizedLine>>{};
    for (final line in lines) {
      byParagraph.putIfAbsent(line.paragraph, () => []).add(line);
    }
    final paragraphs = [
      for (final MapEntry(key: id, value: members) in byParagraph.entries)
        RecognizedLine(
          text: joinParagraph([for (final line in members) line.text]),
          box: members.map((l) => l.box).reduce((a, b) => a.expandToInclude(b)),
          paragraph: id,
        ),
    ];
    final (lines: translations, :status) = await _translator.translateFrame(
      paragraphs,
      target: target,
      sourceLanguages: sourceLanguages,
      current: currentSource,
    );
    final translated = _now();
    var sampling = Duration.zero;
    final shown = [
      for (final translation in translations)
        if (translation.translatedText case final text?)
          _stillParagraph(frame, translation, text, [
            for (final line in byParagraph[translation.line.paragraph]!)
              line.box,
          ], onSampled: (time) => sampling += time),
    ];
    return ReadResult(
      untranslatedLanguages: {
        for (final translation in translations)
          if (translation.translatedText == null) ...{
            ?translation.sourceLanguage,
            for (final model in translation.missingModels) model.bcpCode,
          },
      },
      paragraphs: shown,
      sourceStatus: status,
      imageSize: frame.size,
      rotation: frame.rotation,
      timings: (
        recognition: _since(start, recognized),
        translation: _since(recognized, translated),
        sampling: sampling,
        total: _since(start, _now()),
      ),
    );
  }

  /// The time from [from] to [to], or zero if the clock went backwards.
  static Duration _since(DateTime from, DateTime to) {
    final time = to.difference(from);
    return time.isNegative ? Duration.zero : time;
  }

  ReadParagraph _stillParagraph(
    CameraFrame frame,
    LineTranslation translation,
    String translatedText,
    List<Rect> lineBoxes, {
    required void Function(Duration time) onSampled,
  }) {
    final before = _now();
    final colours = sampleColours(frame, translation.line.box);
    onSampled(_since(before, _now()));
    return ReadParagraph(
      box: translation.line.box,
      lineBoxes: lineBoxes,
      sourceText: translation.line.text,
      sourceLanguage: translation.sourceLanguage,
      translatedText: translatedText,
      background: colours?.background,
      ink: colours?.ink,
    );
  }

  void _report(LiveTranslateException error) {
    if (!_disposed) _errors.add(error);
  }

  void _modelReady(TranslateLanguage language) {
    if (!_disposed) _modelsReady.add(language);
  }

  /// Stops emitting. Reads still running finish, but nothing they report is
  /// delivered. The engines are not closed, because the pipeline doesn't own
  /// them.
  Future<void> dispose() async {
    _disposed = true;
    await _translatorEvents.cancel();
    await Future.wait([
      _errors.close(),
      _modelsReady.close(),
      _modelEvents.close(),
    ]);
  }
}
