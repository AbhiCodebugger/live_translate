import 'dart:async';

import 'package:flutter/material.dart';
import 'package:live_translate/live_translate.dart';

import 'language_picker.dart';
import 'languages.dart';

/// How often the screen checks whether a reported model has arrived.
const modelPollInterval = Duration(seconds: 2);

/// Builds the screen's translation view from its settings.
typedef ViewBuilder =
    LiveTranslateView Function({
      required LiveTranslateController controller,
      required TranslateLanguage? targetLanguage,
      required Set<TranslateLanguage>? sourceLanguages,
      required Set<TextScript> scripts,
      required ResolutionPreset resolution,
      required ValueChanged<LiveTranslateException> onError,
    });

LiveTranslateView _buildView({
  required LiveTranslateController controller,
  required TranslateLanguage? targetLanguage,
  required Set<TranslateLanguage>? sourceLanguages,
  required Set<TextScript> scripts,
  required ResolutionPreset resolution,
  required ValueChanged<LiveTranslateException> onError,
}) => LiveTranslateView(
  controller: controller,
  targetLanguage: targetLanguage,
  sourceLanguages: sourceLanguages,
  scripts: scripts,
  resolution: resolution,
  onError: onError,
);

/// A full-screen camera translating live, with Lens-style controls: a flash
/// toggle, a source and target language pill, and a shutter that freezes.
class CameraScreen extends StatefulWidget {
  /// Creates the camera screen.
  const CameraScreen({
    super.key,
    @visibleForTesting this.models,
    @visibleForTesting this.buildView,
  });

  /// Where to check models. Defaults to ML Kit.
  final TranslationModels? models;

  /// Builds the translation view, so tests can give it a fake camera and
  /// engines. Defaults to a plain [LiveTranslateView].
  final ViewBuilder? buildView;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _controller = LiveTranslateController();
  late final TranslationModels _models;
  // `null` until the user picks one: the view then uses the device language.
  TranslateLanguage? _chosenTarget;

  // The target the view last reported.
  TranslateLanguage? _viewTarget;

  TranslateLanguage? get _target => _chosenTarget ?? _viewTarget;

  // `null` is "Detect language".
  TranslateLanguage? _source;

  // While detecting, the language most shown lines came from.
  TranslateLanguage? _detected;

  bool _torch = false;
  LiveTranslateState _lastState = LiveTranslateState.initializing;

  // Models the view reported missing that aren't on the device yet.
  final _pending = <TranslateLanguage>{};
  Timer? _poll;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _models = widget.models ?? TranslationModels();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final detected = _source == null
        ? detectedLanguage(_controller.lines, _detected)
        : null;
    if (detected != _detected) setState(() => _detected = detected);

    final target = _controller.targetLanguage;
    if (target != _viewTarget) setState(() => _viewTarget = target);

    final state = _controller.state;
    // A camera start or restart turns the torch off.
    if (state == LiveTranslateState.running &&
        _lastState != LiveTranslateState.running &&
        _lastState != LiveTranslateState.frozen &&
        _torch) {
      setState(() => _torch = false);
    }
    _lastState = state;
  }

  Future<void> _toggleTorch() async {
    final on = !_torch;
    await _controller.setTorch(on);
    if (mounted) setState(() => _torch = on);
  }

  Future<void> _shutter() => _controller.state == LiveTranslateState.frozen
      ? _controller.resume()
      : _controller.freeze();

  Future<void> _pickTarget() async {
    final picked = await pickLanguage(
      context,
      title: 'Translate to',
      options: TranslateLanguage.values,
      selected: _target,
      models: _models,
    );
    if (picked case (choice: final TranslateLanguage target)) {
      setState(() => _chosenTarget = target);
    }
  }

  Future<void> _pickSource() async {
    final picked = await pickLanguage(
      context,
      title: 'Translate from',
      options: sourceOptions,
      selected: _source,
      models: _models,
    );
    if (picked case (:final choice)) {
      setState(() {
        _source = choice;
        _detected = choice == null
            ? detectedLanguage(_controller.lines, null)
            : null;
      });
    }
  }

  void _onError(LiveTranslateException error) {
    if (error case ModelNotDownloaded(:final language)) {
      _awaitModel(language);
      return;
    }
    final message = switch (error) {
      UnsupportedLanguagePair(:final source) =>
        "Can't translate from '$source' on this device.",
      CameraPermissionDenied() => 'Allow camera access to translate.',
      CameraUnavailable() => 'No camera available.',
      PipelineFailure(:final cause) => 'Something went wrong: $cause',
      ModelNotDownloaded() => throw StateError('handled above'),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows [language] as downloading until its model is on the device.
  void _awaitModel(TranslateLanguage language) {
    setState(() => _pending.add(language));
    _poll ??= Timer.periodic(modelPollInterval, (_) => _checkPending());
  }

  Future<void> _checkPending() async {
    if (_polling) return;
    _polling = true;
    try {
      final arrived = <TranslateLanguage>{};
      for (final language in _pending.toList()) {
        try {
          if (await _models.isDownloaded(language)) arrived.add(language);
        } on Object {
          // Checked again on the next tick.
        }
      }
      if (!mounted) return;
      setState(() => _pending.removeAll(arrived));
      if (_pending.isEmpty) {
        _poll?.cancel();
        _poll = null;
      }
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reading = readingFor(_source);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            // Only tests pass a builder.
            child: (widget.buildView ?? _buildView)(
              controller: _controller,
              // Sharper frames read small print reliably, at the cost of
              // slower live processing.
              resolution: ResolutionPreset.high,
              targetLanguage: _chosenTarget,
              sourceLanguages: reading.sourceLanguages,
              scripts: reading.scripts,
              onError: _onError,
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(torch: _torch, onTorch: _toggleTorch),
                const SizedBox(height: 12),
                _LanguagePill(
                  source: switch ((_source, _detected)) {
                    (final TranslateLanguage source, _) => displayName(source),
                    (null, final TranslateLanguage detected) => displayName(
                      detected,
                    ),
                    (null, null) => sourceName(null),
                  },
                  detecting: _source == null,
                  target: switch (_target) {
                    final target? => displayName(target),
                    null => '',
                  },
                  sourceBusy: _pending.any((l) => l != _target),
                  targetBusy: _pending.contains(_target),
                  onSource: _pickSource,
                  onTarget: _pickTarget,
                ),
                const Spacer(),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) =>
                      _Shutter(state: _controller.state, onPressed: _shutter),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.torch, required this.onTorch});

  final bool torch;
  final VoidCallback onTorch;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              onPressed: onTorch,
              tooltip: torch ? 'Torch off' : 'Torch on',
              color: Colors.white,
              icon: Icon(torch ? Icons.flash_on : Icons.flash_off),
            ),
          ),
        ),
        const Text(
          'Live Translate',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.source,
    required this.detecting,
    required this.target,
    required this.sourceBusy,
    required this.targetBusy,
    required this.onSource,
    required this.onTarget,
  });

  final String source;
  final bool detecting;
  final String target;
  final bool sourceBusy;
  final bool targetBusy;
  final VoidCallback onSource;
  final VoidCallback onTarget;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(32),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _LanguageChip(
            key: const Key('source-chip'),
            label: source,
            icon: detecting ? Icons.auto_awesome : null,
            busy: sourceBusy,
            onTap: onSource,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward, color: _chipText, size: 20),
        ),
        Flexible(
          child: _LanguageChip(
            key: const Key('target-chip'),
            label: target,
            busy: targetBusy,
            onTap: onTarget,
          ),
        ),
      ],
    ),
  );
}

const _chipFill = Color(0xFFD3E3FD);
const _chipText = Color(0xFF041E49);

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    super.key,
    required this.label,
    required this.busy,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget? leading = busy
        ? const Tooltip(
            message: 'Downloading the language model…',
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _chipText,
              ),
            ),
          )
        : icon == null
        ? null
        : Icon(icon, size: 18, color: _chipText);
    return Material(
      color: _chipFill,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _chipText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.state, required this.onPressed});

  final LiveTranslateState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final frozen = state == LiveTranslateState.frozen;
    final enabled = frozen || state == LiveTranslateState.running;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0x55FFFFFF),
        shape: BoxShape.circle,
      ),
      child: Tooltip(
        message: frozen ? 'Resume' : 'Freeze',
        child: Material(
          color: enabled ? Colors.white : Colors.white54,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: SizedBox.square(
              dimension: 72,
              child: Icon(
                frozen ? Icons.play_arrow : Icons.translate,
                size: 32,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
