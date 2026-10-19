import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;

import '../models/source_status.dart';
import '../models/text_script.dart';
import '../models/translated_paragraph.dart';
import '../pipeline/pipeline_metrics.dart';
import 'live_translate_state.dart';

/// Drives and observes a live translation view.
///
/// Pass it to the view, then call its methods or listen to it:
///
/// ```dart
/// final controller = LiveTranslateController();
///
/// LiveTranslateView(
///   controller: controller,
///   targetLanguage: TranslateLanguage.english,
/// );
///
/// await controller.freeze();
/// final shown = controller.paragraphs.map((p) => p.translatedText);
/// ```
///
/// Calls made before the view is shown, or after it is gone, do nothing.
/// Settings changed here and settings passed to the view follow the most
/// recent change.
class LiveTranslateController extends ChangeNotifier {
  LiveTranslateState _state = LiveTranslateState.initializing;
  List<TranslatedParagraph> _paragraphs = const [];
  TranslateLanguage? _targetLanguage;
  Set<TextScript>? _scripts;
  Set<TranslateLanguage>? _sourceLanguages;
  SourceStatus _sourceStatus = const SourceSearching();
  ControllerHost? _host;
  final _metrics = StreamController<PipelineMetrics>.broadcast();

  /// What the view is doing.
  LiveTranslateState get state => _state;

  /// The paragraphs the view shows, with rectangles in the view's
  /// coordinates.
  List<TranslatedParagraph> get paragraphs => _paragraphs;

  /// The language the view translates into: the one the app chose, or the
  /// device-language default when it chose none.
  ///
  /// `null` until the view has shown its first frame, and again once the
  /// controller is no longer attached to a view. Listeners are notified when
  /// it changes.
  TranslateLanguage? get targetLanguage => _targetLanguage;

  /// The scripts the view reads, as set through the widget or [setScripts],
  /// whichever came last.
  ///
  /// `null` until the view has shown its first frame, and again once the
  /// controller is no longer attached to a view. Listeners are notified when
  /// it changes. The set can't be modified.
  Set<TextScript>? get scripts => _scripts;

  /// The languages the view expects the text to be in, as set through the
  /// widget or [setSourceLanguages], whichever came last.
  ///
  /// `null` while the view detects each paragraph's language, and also when
  /// the controller isn't attached to a view; [scripts] is non-null whenever
  /// it is attached. Listeners are notified when it changes. The set can't
  /// be modified.
  Set<TranslateLanguage>? get sourceLanguages => _sourceLanguages;

  /// Where the attached view stands in finding the language it translates
  /// from: searching, guessed, downloading, ready, unsupported, not found
  /// or download failed. Listeners are notified when it changes. A
  /// controller not attached to a view reports [SourceSearching].
  ///
  /// ```dart
  /// final label = switch (controller.sourceStatus) {
  ///   SourceGuessed(:final language) => '${language.name}?',
  ///   SourceDownloading(:final language) => 'Downloading ${language.name}…',
  ///   _ => '',
  /// };
  /// ```
  SourceStatus get sourceStatus => _sourceStatus;

  /// The metrics of each read the view shows, live or frozen, emitted once
  /// its result is on screen.
  ///
  /// Reads that fail or are replaced before they finish emit nothing, and so
  /// does freezing that keeps the labels already shown. Any number of
  /// listeners may subscribe; the stream closes when the controller is
  /// disposed.
  ///
  /// ```dart
  /// controller.metrics.listen((metrics) {
  ///   debugPrint('${metrics.paragraphs} paragraphs in '
  ///       '${metrics.total.inMilliseconds} ms');
  /// });
  /// ```
  Stream<PipelineMetrics> get metrics => _metrics.stream;

  /// Pauses the preview and translates the frozen picture once, paragraph
  /// by paragraph, in the page's colours. Nothing moves until [resume].
  ///
  /// While the picture is read, [paragraphs] is empty and the view shows a
  /// progress indicator; then [paragraphs] holds one entry per translated
  /// paragraph. Changing the language or scripts while frozen reads the same
  /// picture again. Has no effect unless [state] is
  /// [LiveTranslateState.running].
  Future<void> freeze() => _host?.freeze() ?? Future.value();

  /// Resumes live translation. Has no effect unless [state] is
  /// [LiveTranslateState.frozen].
  Future<void> resume() => _host?.resume() ?? Future.value();

  /// Translates into [language] from now on, without restarting the camera.
  Future<void> setTargetLanguage(TranslateLanguage language) =>
      _host?.setTargetLanguage(language) ?? Future.value();

  /// Reads [scripts] from now on, without restarting the camera.
  Future<void> setScripts(Set<TextScript> scripts) =>
      _host?.setScripts(scripts) ?? Future.value();

  /// Expects text in [languages] from now on, or detects each paragraph's
  /// language when `null`, without restarting the camera. A single language
  /// skips detection entirely.
  ///
  /// ```dart
  /// await controller.setSourceLanguages({TranslateLanguage.hindi});
  /// ```
  Future<void> setSourceLanguages(Set<TranslateLanguage>? languages) =>
      _host?.setSourceLanguages(languages) ?? Future.value();

  /// Turns the torch on or off. Has no effect on a camera without a torch.
  /// The torch turns off whenever the camera restarts.
  Future<void> setTorch(bool on) => _host?.setTorch(on) ?? Future.value();

  @override
  void dispose() {
    unawaited(_metrics.close());
    super.dispose();
  }

  void _publish(
    LiveTranslateState state,
    List<TranslatedParagraph> paragraphs,
    TranslateLanguage target,
    Set<TextScript> scripts,
    Set<TranslateLanguage>? sourceLanguages,
    SourceStatus sourceStatus,
  ) {
    _state = state;
    _paragraphs = List.unmodifiable(paragraphs);
    _targetLanguage = target;
    _scripts = Set.unmodifiable(scripts);
    _sourceLanguages = sourceLanguages == null
        ? null
        : Set.unmodifiable(sourceLanguages);
    _sourceStatus = sourceStatus;
    notifyListeners();
  }
}

/// What a view does for its [LiveTranslateController]. Implemented by the
/// view; not part of the public API.
abstract interface class ControllerHost {
  /// See [LiveTranslateController.freeze].
  Future<void> freeze();

  /// See [LiveTranslateController.resume].
  Future<void> resume();

  /// See [LiveTranslateController.setTargetLanguage].
  Future<void> setTargetLanguage(TranslateLanguage language);

  /// See [LiveTranslateController.setScripts].
  Future<void> setScripts(Set<TextScript> scripts);

  /// See [LiveTranslateController.setSourceLanguages].
  Future<void> setSourceLanguages(Set<TranslateLanguage>? languages);

  /// See [LiveTranslateController.setTorch].
  Future<void> setTorch(bool on);
}

/// Connects [controller] to the view state [host]. A controller drives one
/// view at a time.
void attachController(LiveTranslateController controller, ControllerHost host) {
  assert(
    controller._host == null || identical(controller._host, host),
    'A LiveTranslateController can drive only one view at a time.',
  );
  controller._host = host;
}

/// Disconnects [controller] from [host], if it is attached to it. The
/// controller goes back to reporting [LiveTranslateState.initializing] with
/// no paragraphs and no target language, without notifying: this happens while
/// the view is torn down.
void detachController(LiveTranslateController controller, ControllerHost host) {
  if (!identical(controller._host, host)) return;
  controller
    .._host = null
    .._state = LiveTranslateState.initializing
    .._paragraphs = const []
    .._targetLanguage = null
    .._scripts = null
    .._sourceLanguages = null
    .._sourceStatus = const SourceSearching();
}

/// Updates what [controller] reports, notifying its listeners if anything
/// changed.
void publishToController(
  LiveTranslateController controller, {
  required LiveTranslateState state,
  required List<TranslatedParagraph> paragraphs,
  required TranslateLanguage target,
  Set<TextScript> scripts = const {TextScript.latin, TextScript.devanagari},
  Set<TranslateLanguage>? sourceLanguages,
  SourceStatus sourceStatus = const SourceSearching(),
}) {
  if (state == controller._state &&
      listEquals(paragraphs, controller._paragraphs) &&
      target == controller._targetLanguage &&
      setEquals(scripts, controller._scripts) &&
      setEquals(sourceLanguages, controller._sourceLanguages) &&
      sourceStatus == controller._sourceStatus) {
    return;
  }
  controller._publish(
    state,
    paragraphs,
    target,
    scripts,
    sourceLanguages,
    sourceStatus,
  );
}

/// Emits [metrics] on [controller]'s [LiveTranslateController.metrics], if
/// it is attached to a view and not disposed.
void publishMetrics(
  LiveTranslateController controller,
  PipelineMetrics metrics,
) {
  if (controller._host == null || controller._metrics.isClosed) return;
  controller._metrics.add(metrics);
}
