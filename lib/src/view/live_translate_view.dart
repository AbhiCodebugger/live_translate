import 'dart:async';
import 'dart:collection' show Queue;

import 'package:camera/camera.dart' show ResolutionPreset;
import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code, TranslateLanguage;
import 'package:meta/meta.dart' show internal;

import '../cache/translation_cache.dart';
import '../camera/camera_frame.dart';
import '../camera/camera_session.dart';
import '../controller/live_translate_controller.dart';
import '../controller/live_translate_state.dart';
import '../engines/language_engine.dart';
import '../engines/mlkit/mlkit_language_engine.dart';
import '../engines/mlkit/mlkit_model_store.dart';
import '../engines/mlkit/mlkit_text_engine.dart';
import '../engines/mlkit/mlkit_translate_engine.dart';
import '../engines/model_store.dart';
import '../engines/multi_script_text_engine.dart';
import '../engines/text_engine.dart';
import '../engines/translate_engine.dart';
import '../errors.dart';
import '../geometry/coordinate_mapper.dart';
import '../geometry/image_rotation.dart';
import '../models/device_language.dart';
import '../models/overlay_style.dart';
import '../models/source_status.dart';
import '../models/text_script.dart';
import '../models/translated_paragraph.dart';
import '../pipeline/line_translator.dart';
import '../pipeline/pipeline.dart';
import '../pipeline/pipeline_metrics.dart';
import '../still/read_result.dart';
import '../live/live_settler.dart';
import '../motion/motion_estimator.dart';
import 'debug_hud.dart';
import 'paragraph_ids.dart';
import 'paragraph_painter.dart';
import 'text_fit.dart';

/// Builds the engines a [LiveTranslateView] uses.
///
/// The text, language and translate engines are rebuilt whenever the view's
/// settings change; the model store lives as long as the view.
typedef LiveTranslateEngines = ({
  TextEngine Function(Set<TextScript> scripts) text,
  LanguageEngine Function() language,
  TranslateEngine Function() translate,
  ModelStore models,
});

/// The ML Kit engines used outside tests.
LiveTranslateEngines mlKitEngines() => (
  text: (scripts) => MultiScriptTextEngine({
    for (final script in scripts) script: MlKitTextEngine(script: script),
  }),
  language: MlKitLanguageEngine.new,
  translate: MlKitTranslateEngine.new,
  models: MlKitModelStore(),
);

/// Builds an app's own overlay from the paragraphs a [LiveTranslateView]
/// shows.
///
/// The widget it returns is laid over the whole view, so each paragraph's
/// [TranslatedParagraph.rect] is a position inside it, for example with
/// [Positioned.fromRect]. Paragraphs fade out by lowering their
/// [TranslatedParagraph.opacity], which the overlay should honour.
typedef OverlayBuilder =
    Widget Function(BuildContext context, List<TranslatedParagraph> paragraphs);

/// Shows the live camera and, once the picture settles, each paragraph of
/// text translated in place, held still while the camera moves a little.
///
/// ```dart
/// // Translates into the device's language.
/// const LiveTranslateView();
///
/// // Hindi signage into English.
/// const LiveTranslateView(
///   targetLanguage: TranslateLanguage.english,
///   sourceLanguages: {TranslateLanguage.hindi},
///   scripts: {TextScript.devanagari},
/// );
/// ```
///
/// Pass a [LiveTranslateController] to freeze the view, change its settings
/// or read the paragraphs it shows.
class LiveTranslateView extends StatefulWidget {
  /// Creates the view.
  const LiveTranslateView({
    super.key,
    this.targetLanguage,
    this.scripts = const {TextScript.latin, TextScript.devanagari},
    this.sourceLanguages,
    this.resolution = ResolutionPreset.medium,
    this.style = const OverlayStyle(),
    this.onError,
    this.overlayBuilder,
    this.onParagraphsChanged,
    this.onFrozen,
    this.placeholderBuilder,
    this.showDebugHud = false,
    this.controller,
    @internal this.createSession,
    @internal this.createEngines,
    @internal this.now,
    @internal this.elapsed,
  });

  /// The language paragraphs are translated into, or `null` for the device's
  /// language (English when the device language can't be translated
  /// on-device).
  final TranslateLanguage? targetLanguage;

  /// The scripts to read, Latin and Devanagari by default. Each read uses
  /// all of them.
  final Set<TextScript> scripts;

  /// The languages the text is expected to be in, or `null` to detect each
  /// paragraph's language. A single language skips detection entirely.
  final Set<TranslateLanguage>? sourceLanguages;

  /// The capture resolution. Changing it restarts the camera at the new
  /// resolution.
  final ResolutionPreset resolution;

  /// How translated labels look. Unused when [overlayBuilder] is given.
  final OverlayStyle style;

  /// Called with every problem: camera errors, missing models, unsupported
  /// languages and processing failures.
  final ValueChanged<LiveTranslateException>? onError;

  /// Draws the translations in place of the built-in labels, or `null` for
  /// the built-in labels.
  ///
  /// It is laid over the whole view, above the preview, and rebuilt with the
  /// shown paragraphs whenever they change. [style] is not used when it is
  /// given.
  ///
  /// ```dart
  /// LiveTranslateView(
  ///   overlayBuilder: (context, paragraphs) => Stack(
  ///     children: [
  ///       for (final paragraph in paragraphs)
  ///         Positioned.fromRect(
  ///           key: ValueKey(paragraph.id),
  ///           rect: paragraph.rect,
  ///           child: Opacity(
  ///             opacity: paragraph.opacity,
  ///             child: ColoredBox(
  ///               color: Colors.yellow,
  ///               child: Text(paragraph.translatedText),
  ///             ),
  ///           ),
  ///         ),
  ///     ],
  ///   ),
  /// );
  /// ```
  final OverlayBuilder? overlayBuilder;

  /// Called after a frame with the shown paragraphs whenever they change: a
  /// new result, labels following the camera, each step of a fade, and
  /// clearing.
  ///
  /// These are the paragraphs a [LiveTranslateController] reports, and this
  /// works without one. While labels move or fade it is called on every
  /// frame; compare [TranslatedParagraph.translatedText] to react only to
  /// new text.
  final ValueChanged<List<TranslatedParagraph>>? onParagraphsChanged;

  /// Called once the frozen picture's translation is shown, with its
  /// paragraphs.
  ///
  /// That is right away when freezing keeps the labels already shown, and
  /// after the frozen picture has been read otherwise. It is called again
  /// each time the frozen picture is read again, after a settings change or
  /// a model download, so update what it opened rather than opening it
  /// twice. It isn't called when reading fails; [onError] is.
  final ValueChanged<List<TranslatedParagraph>>? onFrozen;

  /// Builds what is shown while the camera starts, and while it restarts
  /// after the app returns from the background. Defaults to a progress
  /// indicator. Camera errors are shown instead of it.
  final WidgetBuilder? placeholderBuilder;

  /// Whether to show a small panel of performance numbers in the top-left
  /// corner, for development: the latest read's total time and the time its
  /// stages took (recognition, translation and colour sampling), how many
  /// paragraphs it translated, how many camera frames the view measured in
  /// the last second, and the mean and worst time its own work took per
  /// frame on the UI thread. Off by default.
  ///
  /// The same numbers reach code through [LiveTranslateController.metrics].
  final bool showDebugHud;

  /// Drives and observes this view: its state, paragraphs, freezing, settings
  /// and torch. Settings changed through it and settings passed here
  /// follow the most recent change.
  final LiveTranslateController? controller;

  /// Builds the camera session. Defaults to the camera plugin.
  ///
  /// For this package's tests only.
  @internal
  final CameraSession Function(ResolutionPreset resolution)? createSession;

  /// Builds the recognition and translation engines. Defaults to ML Kit.
  ///
  /// For this package's tests only.
  @internal
  final LiveTranslateEngines Function()? createEngines;

  /// The clock deciding when the picture has settled. Defaults to the
  /// system clock.
  ///
  /// For this package's tests only.
  @internal
  final DateTime Function()? now;

  /// A steadily increasing clock that times the view's per-frame work for
  /// the debug HUD. Defaults to a stopwatch.
  ///
  /// For this package's tests only.
  @internal
  final Duration Function()? elapsed;

  @override
  State<LiveTranslateView> createState() => _LiveTranslateViewState();
}

class _LiveTranslateViewState extends State<LiveTranslateView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin
    implements ControllerHost {
  // Replaced when the resolution changes.
  late CameraSession _session;
  late ResolutionPreset _sessionResolution;
  Future<void> _cameraChange = Future.value();
  late final LiveTranslateEngines _engines;
  late final LiveSettler _settler;

  // Times reads: the test clock when given, otherwise a monotonic one.
  late final DateTime Function() _clock;
  final _estimator = MotionEstimator();
  late final AnimationController _fade;

  // Effective settings: the most recent change wins, whether it came from a
  // widget parameter or the controller.
  late TranslateLanguage _target;
  late Set<TextScript> _scripts;
  Set<TranslateLanguage>? _sourceLanguages;

  // Rebuilt whenever the target, scripts or source languages change.
  late TextEngine _textEngine;
  late LanguageEngine _languageEngine;
  late TranslateEngine _translateEngine;
  late Pipeline _pipeline;
  final _subscriptions = <StreamSubscription<Object>>[];
  StreamSubscription<CameraFrame>? _frameSubscription;

  bool _running = false;
  bool _suspended = false;
  bool _frozen = false;
  LiveTranslateException? _error;

  // The latest live frame. Frozen, it stays the frame that was frozen.
  // Cleared when the camera stops, so an earlier session's frame is never
  // read.
  CameraFrame? _lastFrame;

  // The result shown, with the frame it was read from and each paragraph's
  // id, and how far the picture has moved since that frame.
  ({ReadResult result, CameraFrame frame, List<String> ids})? _shown;
  Offset _shift = Offset.zero;

  // Whether the next result keeps the ids of the paragraphs shown in the
  // same place: not after a clear, a camera start or stop, or a resume.
  bool _idsCarryOver = false;

  // The paragraphs shown just before a freeze dropped them to read, so the
  // frozen result keeps their ids.
  List<PlacedParagraph> _previous = const [];
  int _nextId = 0;

  // Each read gets a token; a read whose token is no longer current
  // (cleared, re-read, resumed or stopped since) is ignored.
  bool _reading = false;

  // Languages whose model became ready while the current read ran: if that
  // read lacked one of them, it is read again once it finishes.
  final _readyDuringRead = <String>{};
  int _readToken = 0;

  // What the controller and callbacks are told after the next frame.
  List<TranslatedParagraph> _shownParagraphs = const [];
  List<TranslatedParagraph> _reportedParagraphs = const [];
  bool _reportScheduled = false;

  // Whether the frozen picture's result is shown but onFrozen hasn't been
  // called with it yet.
  bool _frozenPending = false;

  // Where finding the source language stands, and how many reads of the
  // current scene in a row found no language.
  SourceStatus _sourceStatus = const SourceSearching();
  int _readsWithoutLanguage = 0;

  // The latest shown read's metrics, and whether the controller still has
  // to hear about them.
  PipelineMetrics? _latestMetrics;
  PipelineMetrics? _pendingMetrics;

  // The debug HUD, only while it is shown: what it displays, a timer that
  // lets the frame rate fall when frames stop, and when the live frames of
  // the last second arrived and how long the view's work on each took.
  ValueNotifier<DebugHudData>? _hud;
  Timer? _hudTimer;
  final _frameTimes = Queue<({DateTime at, Duration cost})>();
  late final Duration Function() _elapsed;

  // The built-in labels' text layouts, kept while they follow the camera.
  final _labelLayouts = LabelLayoutCache();

  LiveTranslateState get _state {
    if (_error != null) return LiveTranslateState.error;
    if (!_running) return LiveTranslateState.initializing;
    if (_frozen) return LiveTranslateState.frozen;
    return LiveTranslateState.running;
  }

  /// The widget's target, or the device language when it has none.
  TranslateLanguage get _widgetTarget =>
      widget.targetLanguage ??
      deviceTargetLanguage(WidgetsBinding.instance.platformDispatcher.locale);

  @override
  void initState() {
    super.initState();
    _target = _widgetTarget;
    _scripts = widget.scripts;
    _sourceLanguages = widget.sourceLanguages;
    _settler = LiveSettler(now: widget.now);
    if (widget.now case final now?) {
      _clock = now;
    } else {
      final epoch = DateTime.now();
      final watch = Stopwatch()..start();
      _clock = () => epoch.add(watch.elapsed);
    }
    if (widget.elapsed case final elapsed?) {
      _elapsed = elapsed;
    } else {
      final watch = Stopwatch()..start();
      _elapsed = () => watch.elapsed;
    }
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    )..addListener(_onFade);
    _session = _createSession(widget.resolution);
    _engines = widget.createEngines?.call() ?? mlKitEngines();
    _frameSubscription = _session.frames.listen(_onFrame);
    _syncHud();
    _buildPipeline();
    if (widget.controller case final controller?) {
      attachController(controller, this);
    }
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void didUpdateWidget(LiveTranslateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller case final old?) detachController(old, this);
      if (widget.controller case final controller?) {
        attachController(controller, this);
      }
      _scheduleReport();
    }

    var rebuild = false;
    if (oldWidget.targetLanguage != widget.targetLanguage &&
        _widgetTarget != _target) {
      _target = _widgetTarget;
      rebuild = true;
    }
    if (!setEquals(oldWidget.scripts, widget.scripts) &&
        !setEquals(widget.scripts, _scripts)) {
      _scripts = widget.scripts;
      rebuild = true;
    }
    if (!setEquals(oldWidget.sourceLanguages, widget.sourceLanguages) &&
        !setEquals(widget.sourceLanguages, _sourceLanguages)) {
      _sourceLanguages = widget.sourceLanguages;
      rebuild = true;
    }
    if (rebuild) _replacePipeline();
    if (oldWidget.showDebugHud != widget.showDebugHud) _syncHud();
    if (oldWidget.resolution != widget.resolution) {
      // Restarts run one after another; each starts the latest resolution.
      _cameraChange = _cameraChange.then((_) => _restartCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused:
        if (_suspended) return;
        _suspended = true;
        unawaited(_stop());
      case AppLifecycleState.resumed:
        if (!_suspended) return;
        _suspended = false;
        unawaited(_start());
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    if (widget.controller case final controller?) {
      detachController(controller, this);
    }
    WidgetsBinding.instance.removeObserver(this);
    _readToken++;
    _fade.dispose();
    _hudTimer?.cancel();
    _hud?.dispose();
    _labelLayouts.dispose();
    unawaited(_frameSubscription?.cancel());
    unawaited(_tearDownPipeline());
    unawaited(_session.dispose());
    super.dispose();
  }

  // Live: measure every frame, read once the picture settles.

  void _onFrame(CameraFrame frame) {
    if (!_running || _frozen || frame.generation != _session.generation) {
      return;
    }
    _lastFrame = frame;
    // The HUD times the view's own work on the frame: measuring its motion
    // and deciding whether to read.
    final timed = _hud != null;
    final started = timed ? _elapsed() : Duration.zero;
    final action = _settler.onFrame(
      _estimator.measure(frame),
      frame.rotation.upright(frame.size),
    );
    if (timed) {
      _frameTimes.add((at: _clock(), cost: _elapsed() - started));
      _updateHud();
    }
    switch (action) {
      case SettleAction.read:
        _settler.readStarted();
        unawaited(_read(frame));
      case SettleAction.clear:
        _readToken++;
        _reading = false;
        _forgetIds();
        _resetSourceStatus();
        if (_shown != null) unawaited(_fade.animateTo(0));
      case SettleAction.none:
        break;
    }
    // Follow the picture, rebuilding only for a visible move.
    if (_shown != null && (_settler.offset - _shift).distance >= 1) {
      setState(() => _shift = _settler.offset);
    }
  }

  /// Once a clear has faded the labels out, drops them.
  void _onFade() {
    if (_fade.value == 0 && _shown != null && mounted) {
      setState(() => _shown = null);
    } else if (_shown != null) {
      setState(() {});
    }
  }

  /// Reads [frame] and shows its result, unless something replaced the read
  /// meanwhile. Frozen, the result is shown at [frozenShift]; live, at the
  /// shift the settler has added up since [frame].
  Future<void> _read(CameraFrame frame, {Offset? frozenShift}) async {
    final token = ++_readToken;
    _readyDuringRead.clear();
    _frozenPending = false;
    setState(() => _reading = true);
    final ReadResult? result;
    try {
      result = await _pipeline.read(
        frame,
        currentSource: _namedTag(_sourceStatus),
      );
    } catch (error, stackTrace) {
      // A superseded read may fail because its engines were closed.
      if (!mounted || token != _readToken) return;
      if (!_frozen) _settler.readFinished(success: false);
      setState(() => _reading = false);
      _report(
        error is LiveTranslateException
            ? error
            : PipelineFailure(error, stackTrace),
      );
      return;
    }
    if (!mounted || token != _readToken) return;
    if (!_frozen) _settler.readFinished(success: result != null);
    setState(() {
      _reading = false;
      if (_frozen) _frozenPending = true;
      if (result == null) return;
      _takeSourceStatus(result.sourceStatus);
      final timings = result.timings;
      _latestMetrics = _pendingMetrics = PipelineMetrics(
        recognition: timings.recognition,
        translation: timings.translation,
        sampling: timings.sampling,
        total: timings.total,
        paragraphs: result.paragraphs.length,
        frozen: _frozen,
      );
      _updateHud();
      final shift = frozenShift ?? _settler.offset;
      final ids = matchParagraphIds(
        [for (final paragraph in result.paragraphs) paragraph.box.shift(shift)],
        _placedNow(),
        () => 'p${_nextId++}',
      );
      _shown = (result: result, frame: frame, ids: ids);
      _previous = const [];
      _idsCarryOver = true;
      _shift = shift;
      _fade.value = 1;
    });
    if (result != null &&
        result.untranslatedLanguages.any(_readyDuringRead.contains)) {
      _readyDuringRead.clear();
      _reread();
    }
  }

  /// The shown paragraphs where they are now, for the next result to keep
  /// their ids.
  List<PlacedParagraph> _placedNow() {
    final shown = _shown;
    if (shown == null || !_idsCarryOver) return _previous;
    return [
      for (final (i, paragraph) in shown.result.paragraphs.indexed)
        (id: shown.ids[i], box: paragraph.box.shift(_shift)),
    ];
  }

  /// Gives the next result new ids, as after a new scene.
  void _forgetIds() {
    _idsCarryOver = false;
    _previous = const [];
  }

  /// Moves the source status on from a read's [status], `null` when the read
  /// found no language: after three such reads in a row, nothing is found.
  void _takeSourceStatus(SourceStatus? status) {
    if (status == null) {
      _readsWithoutLanguage++;
      _setSourceStatus(
        _readsWithoutLanguage >= _readsBeforeNotFound ||
                _sourceStatus is SourceNotFound
            ? const SourceNotFound()
            : const SourceSearching(),
      );
    } else {
      _readsWithoutLanguage = 0;
      _setSourceStatus(status);
    }
  }

  /// Starts looking for the source language again, as for a new scene.
  void _resetSourceStatus() {
    _readsWithoutLanguage = 0;
    _setSourceStatus(const SourceSearching());
  }

  /// Shows [status], and keeps reading a steady picture while it is still
  /// searching or guessing.
  void _setSourceStatus(SourceStatus status) {
    _settler.unsettled = status is SourceSearching || status is SourceGuessed;
    if (status == _sourceStatus) return;
    _sourceStatus = status;
    _scheduleReport();
    // The report goes out after a frame, which a model event alone
    // doesn't bring.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Moves the status on as soon as the named language's download starts,
  /// completes or fails, without waiting for the next read.
  void _onModelEvent(({TranslateLanguage language, ModelEvent event}) event) {
    if (_namedTag(_sourceStatus) != event.language.bcpCode) return;
    if (_sourceStatus is SourceReady) return;
    _setSourceStatus(switch (event.event) {
      ModelEvent.started => SourceDownloading(event.language),
      ModelEvent.ready => SourceReady(event.language),
      ModelEvent.failed => SourceDownloadFailed(event.language),
    });
  }

  /// Reads the shown result's frame again, as after a settings change or a
  /// completed download, keeping its labels where they are meanwhile.
  void _reread() {
    final shown = _shown;
    if (shown == null) return;
    if (_frozen) {
      unawaited(_read(shown.frame, frozenShift: _shift));
    } else {
      _settler
        ..readCancelled()
        ..readStarted(shiftSince: _settler.offset);
      unawaited(_read(shown.frame));
    }
  }

  void _onModelReady(TranslateLanguage language) {
    if (_reading) {
      _readyDuringRead.add(language.bcpCode);
      return;
    }
    final shown = _shown;
    if (shown == null) return;
    if (shown.result.untranslatedLanguages.contains(language.bcpCode)) {
      _reread();
    }
  }

  // Debug HUD.

  /// Creates or drops the HUD to match [LiveTranslateView.showDebugHud].
  void _syncHud() {
    if (widget.showDebugHud && _hud == null) {
      _hud = ValueNotifier((
        latest: _latestMetrics,
        framesPerSecond: 0,
        frameCost: null,
      ));
      _hudTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _updateHud(),
      );
    } else if (!widget.showDebugHud && _hud != null) {
      _hudTimer?.cancel();
      _hudTimer = null;
      _hud!.dispose();
      _hud = null;
      _frameTimes.clear();
    }
  }

  /// Shows the latest read, and the live frames of the last second and
  /// their cost.
  void _updateHud() {
    final hud = _hud;
    if (hud == null) return;
    final since = _clock().subtract(const Duration(seconds: 1));
    while (_frameTimes.isNotEmpty && !_frameTimes.first.at.isAfter(since)) {
      _frameTimes.removeFirst();
    }
    var total = Duration.zero;
    var worst = Duration.zero;
    for (final (at: _, :cost) in _frameTimes) {
      total += cost;
      if (cost > worst) worst = cost;
    }
    hud.value = (
      latest: _latestMetrics,
      framesPerSecond: _frameTimes.length,
      frameCost: _frameTimes.isEmpty
          ? null
          : (mean: total ~/ _frameTimes.length, worst: worst),
    );
  }

  // ControllerHost: what the controller asks of the view.

  @override
  Future<void> freeze() async {
    if (_state != LiveTranslateState.running) return;
    if (_shown != null && _settler.canKeepOnFreeze) {
      // The labels already match the picture: keep them as they are.
      setState(() {
        _frozen = true;
        _frozenPending = true;
      });
    } else {
      final frame = _lastFrame;
      _readToken++;
      _settler.readCancelled();
      _previous = _placedNow();
      setState(() {
        _frozen = true;
        _shown = null;
        _reading = false;
        // With no frame to read, there is nothing to wait for.
        _frozenPending = frame == null;
      });
      if (frame != null) unawaited(_read(frame, frozenShift: Offset.zero));
    }
    _fade.value = 1;
    try {
      await _session.pause();
    } on LiveTranslateException catch (error) {
      // The view stays frozen: its labels already hold still.
      _report(error);
    }
  }

  @override
  Future<void> resume() async {
    if (_state != LiveTranslateState.frozen) return;
    _readToken++;
    _settler.reset();
    _estimator.reset();
    _forgetIds();
    _resetSourceStatus();
    LiveTranslateException? failure;
    try {
      await _session.resume();
    } on LiveTranslateException catch (error) {
      failure = error;
      _report(error);
    }
    if (mounted) {
      setState(() {
        _frozen = false;
        _frozenPending = false;
        _shown = null;
        _reading = false;
        // The camera's state is unknown: show the error, as after a failed
        // start. Coming back from the background starts it again.
        _error = failure ?? _error;
      });
    }
  }

  @override
  Future<void> setTargetLanguage(TranslateLanguage language) async {
    if (language == _target) return;
    setState(() => _target = language);
    _replacePipeline();
  }

  @override
  Future<void> setScripts(Set<TextScript> scripts) async {
    if (setEquals(scripts, _scripts)) return;
    setState(() => _scripts = Set.of(scripts));
    _replacePipeline();
  }

  @override
  Future<void> setSourceLanguages(Set<TranslateLanguage>? languages) async {
    if (setEquals(languages, _sourceLanguages)) return;
    setState(
      () => _sourceLanguages = languages == null ? null : Set.of(languages),
    );
    _replacePipeline();
  }

  @override
  Future<void> setTorch(bool on) async {
    if (!_running || _error != null) return;
    await _session.setTorch(on);
  }

  // Pipeline.

  void _replacePipeline() {
    unawaited(_tearDownPipeline());
    _buildPipeline();
    _resetSourceStatus();
    // Results of reads from before the change are discarded; a shown result
    // is read again with the new settings.
    _readToken++;
    _reading = false;
    if (_shown != null) {
      _reread();
    } else if (_frozen && _lastFrame != null) {
      unawaited(_read(_lastFrame!, frozenShift: Offset.zero));
    } else {
      _settler.readCancelled();
    }
  }

  void _buildPipeline() {
    _textEngine = _engines.text(_scripts);
    _languageEngine = _engines.language();
    _translateEngine = _engines.translate();
    final languageEngine = _languageEngine;
    final translateEngine = _translateEngine;
    _pipeline = Pipeline(
      textEngine: _textEngine,
      createTranslator: (onError, onModelReady) => LineTranslator(
        languageEngine: languageEngine,
        translateEngine: translateEngine,
        modelStore: _engines.models,
        onError: onError,
        onModelReady: onModelReady,
      ),
      target: _target,
      sourceLanguages: _sourceLanguages,
      now: _clock,
    );
    _subscriptions.addAll([
      _pipeline.errors.listen(_report),
      _pipeline.modelsReady.listen(_onModelReady),
      _pipeline.modelEvents.listen(_onModelEvent),
    ]);
  }

  /// Stops the current pipeline and closes its engines.
  ///
  /// A read still inside a closed engine fails quietly, because its token is
  /// no longer current.
  Future<void> _tearDownPipeline() async {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    unawaited(_pipeline.dispose());
    await Future.wait([
      _textEngine.close(),
      _languageEngine.close(),
      _translateEngine.close(),
    ]);
  }

  // Camera.

  CameraSession _createSession(ResolutionPreset resolution) {
    _sessionResolution = resolution;
    return widget.createSession?.call(resolution) ??
        PluginCameraSession(resolution: resolution);
  }

  /// Replaces the camera session with one at the widget's resolution, and
  /// starts it unless the app is in the background, where resuming will.
  Future<void> _restartCamera() async {
    if (!mounted || widget.resolution == _sessionResolution) return;
    final old = _session;
    // As in dispose: the old session's frames stop with it.
    unawaited(_frameSubscription?.cancel());
    _frameSubscription = null;
    setState(() {
      _running = false;
      _forget();
    });
    await old.stop();
    await old.dispose();
    if (!mounted) return;
    _session = _createSession(widget.resolution);
    _frameSubscription = _session.frames.listen(_onFrame);
    if (!_suspended) await _start();
  }

  /// Forgets everything read, as the camera starts or stops.
  void _forget() {
    _readToken++;
    _lastFrame = null;
    _settler.reset();
    _estimator.reset();
    _shown = null;
    _reading = false;
    _frozen = false;
    _frozenPending = false;
    _forgetIds();
    _resetSourceStatus();
  }

  Future<void> _start() async {
    // Nothing to clear on the first start, which runs from initState where
    // setState isn't allowed.
    if (_running || _shown != null || _frozen) {
      setState(() {
        _running = false;
        _forget();
      });
    } else {
      _forget();
    }
    try {
      await _session.start();
    } on LiveTranslateException catch (error) {
      _report(error);
      if (mounted) setState(() => _error = error);
      return;
    }
    if (mounted) {
      setState(() {
        _running = true;
        _error = null;
      });
    }
  }

  Future<void> _stop() async {
    setState(() {
      _running = false;
      _forget();
    });
    await _session.stop();
  }

  void _report(LiveTranslateException error) => widget.onError?.call(error);

  /// The language [paragraph] was translated from. A read only translates a
  /// paragraph whose language has a translation model, so its tag parses.
  static TranslateLanguage _translatedFrom(ReadParagraph paragraph) {
    final tag = paragraph.sourceLanguage;
    final language = tag == null ? null : BCP47Code.fromRawValue(tag);
    assert(language != null, 'A translated paragraph has source "$tag"');
    return language!;
  }

  /// Tells the controller and the callbacks what is shown, after this
  /// frame: they may call setState, which isn't allowed during build.
  void _scheduleReport() {
    if (_reportScheduled ||
        (widget.controller == null &&
            widget.onParagraphsChanged == null &&
            widget.onFrozen == null)) {
      return;
    }
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!mounted) return;
      final paragraphs = _shownParagraphs;
      if (widget.controller case final controller?) {
        publishToController(
          controller,
          state: _state,
          paragraphs: paragraphs,
          target: _target,
          scripts: _scripts,
          sourceLanguages: _sourceLanguages,
          sourceStatus: _sourceStatus,
        );
        if (_pendingMetrics case final metrics?) {
          publishMetrics(controller, metrics);
        }
      }
      _pendingMetrics = null;
      if (!listEquals(paragraphs, _reportedParagraphs)) {
        _reportedParagraphs = paragraphs;
        widget.onParagraphsChanged?.call(paragraphs);
      }
      if (_frozenPending && _frozen && !_reading) {
        _frozenPending = false;
        widget.onFrozen?.call(paragraphs);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null || !_running) _shownParagraphs = const [];
    _scheduleReport();
    if (_error case final error?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('$error', textAlign: TextAlign.center),
        ),
      );
    }
    if (!_running) {
      if (widget.placeholderBuilder case final placeholder?) {
        return SizedBox.expand(child: placeholder(context));
      }
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = constraints.biggest;
        final shown = _shown;
        final mapper = CoordinateMapper(
          imageSize:
              shown?.result.imageSize ??
              _session.uprightPreviewSize ??
              Size.zero,
          rotation: shown?.result.rotation ?? ImageRotation.deg0,
          viewSize: viewSize,
        );
        final opacity = _fade.value;
        Rect place(Rect box) => mapper.mapToView(box.shift(_shift));
        final paragraphs = [
          if (shown != null)
            for (final (i, paragraph) in shown.result.paragraphs.indexed)
              if (normalizeLineText(paragraph.translatedText) !=
                  normalizeLineText(paragraph.sourceText))
                (id: shown.ids[i], paragraph: paragraph),
        ];
        _shownParagraphs = List.unmodifiable([
          for (final (:id, :paragraph) in paragraphs)
            TranslatedParagraph(
              id: id,
              sourceText: paragraph.sourceText,
              translatedText: paragraph.translatedText,
              sourceLanguage: _translatedFrom(paragraph),
              rect: place(paragraph.box),
              opacity: opacity,
            ),
        ]);
        _scheduleReport();
        final overlay = widget.overlayBuilder;
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: mapper.layout.previewRect,
                child: _session.buildPreview(),
              ),
              if (overlay != null)
                Positioned.fill(child: overlay(context, _shownParagraphs))
              else
                CustomPaint(
                  painter: ParagraphPainter(
                    labels: [
                      for (final (id: _, :paragraph) in paragraphs)
                        ParagraphLabel(
                          rect: place(paragraph.box),
                          lineHeight: _median([
                            for (final box in paragraph.lineBoxes)
                              mapper.mapToView(box).height,
                          ]),
                          text: paragraph.translatedText,
                          background:
                              paragraph.background ??
                              widget.style.backgroundColor,
                          ink: paragraph.ink ?? widget.style.textColor,
                          opacity: opacity,
                        ),
                    ],
                    style: widget.style,
                    textDirection: textDirectionFor(_target),
                    layoutCache: _labelLayouts,
                  ),
                ),
              if (_frozen && _reading)
                const Center(child: CircularProgressIndicator()),
              if (_hud case final hud?) DebugHud(data: hud),
            ],
          ),
        );
      },
    );
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }
}

/// How many reads of a scene in a row must find no language before the
/// source status says nothing was found.
const _readsBeforeNotFound = 3;

/// The BCP-47 tag of the language [status] names, if any.
String? _namedTag(SourceStatus status) => switch (status) {
  SourceSearching() || SourceNotFound() => null,
  SourceGuessed(:final language) ||
  SourceDownloading(:final language) ||
  SourceReady(:final language) ||
  SourceDownloadFailed(:final language) => language.bcpCode,
  SourceUnsupported(:final tag) => tag,
};
