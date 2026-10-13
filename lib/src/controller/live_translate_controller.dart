import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;

import '../models/text_script.dart';
import '../models/translated_line.dart';
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
/// final shown = controller.lines.map((line) => line.translatedText);
/// ```
///
/// Calls made before the view is shown, or after it is gone, do nothing.
/// Settings changed here and settings passed to the view follow the most
/// recent change.
class LiveTranslateController extends ChangeNotifier {
  LiveTranslateState _state = LiveTranslateState.initializing;
  List<TranslatedLine> _lines = const [];
  TranslateLanguage? _targetLanguage;
  ControllerHost? _host;

  /// What the view is doing.
  LiveTranslateState get state => _state;

  /// The lines the view shows, with rectangles in the view's coordinates.
  List<TranslatedLine> get lines => _lines;

  /// The language the view translates into: the one the app chose, or the
  /// device-language default when it chose none.
  ///
  /// `null` until the view has shown its first frame, and again once the
  /// controller is no longer attached to a view. Listeners are notified when
  /// it changes.
  TranslateLanguage? get targetLanguage => _targetLanguage;

  /// Pauses the preview and translates the frozen picture once, paragraph
  /// by paragraph, in the page's colours. Nothing moves until [resume].
  ///
  /// While the picture is read, [lines] is empty and the view shows a
  /// progress indicator; then [lines] holds one entry per translated
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

  /// Turns the torch on or off. Has no effect on a camera without a torch.
  /// The torch turns off whenever the camera restarts.
  Future<void> setTorch(bool on) => _host?.setTorch(on) ?? Future.value();

  void _publish(
    LiveTranslateState state,
    List<TranslatedLine> lines,
    TranslateLanguage target,
  ) {
    _state = state;
    _lines = List.unmodifiable(lines);
    _targetLanguage = target;
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
/// no lines and no target language, without notifying: this happens while
/// the view is torn down.
void detachController(LiveTranslateController controller, ControllerHost host) {
  if (!identical(controller._host, host)) return;
  controller
    .._host = null
    .._state = LiveTranslateState.initializing
    .._lines = const []
    .._targetLanguage = null;
}

/// Updates what [controller] reports, notifying its listeners if anything
/// changed.
void publishToController(
  LiveTranslateController controller, {
  required LiveTranslateState state,
  required List<TranslatedLine> lines,
  required TranslateLanguage target,
}) {
  if (state == controller._state &&
      listEquals(lines, controller._lines) &&
      target == controller._targetLanguage) {
    return;
  }
  controller._publish(state, lines, target);
}
