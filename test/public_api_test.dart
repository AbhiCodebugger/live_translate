import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
// The only package import: everything below must resolve through it.
import 'package:live_translate/live_translate.dart';

void main() {
  test('the entry library exposes the public models', () {
    const line = TranslatedParagraph(
      id: 'a',
      sourceText: 'Hola',
      translatedText: 'Hello',
      sourceLanguage: TranslateLanguage.spanish,
      rect: Rect.zero,
    );
    expect(line.opacity, 1.0);
    expect(const OverlayStyle(), isA<OverlayStyle>());
    expect(TextScript.values, hasLength(2));
  });

  test('the entry library exposes every source status', () {
    final statuses = <SourceStatus>[
      const SourceSearching(),
      const SourceGuessed(TranslateLanguage.spanish),
      const SourceDownloading(TranslateLanguage.spanish),
      const SourceReady(TranslateLanguage.spanish),
      const SourceUnsupported('la'),
      const SourceNotFound(),
      const SourceDownloadFailed(TranslateLanguage.spanish),
    ];
    expect(statuses.toSet(), hasLength(7));
  });

  test('the README source status label compiles and covers every stage', () {
    // Mirrors the "Following language detection" recipe in README.md.
    final controller = LiveTranslateController();
    addTearDown(controller.dispose);
    String sourceLabel() => switch (controller.sourceStatus) {
      SourceSearching() => 'Looking for text…',
      SourceGuessed(:final language) => '${language.name}?',
      SourceDownloading(:final language) => 'Downloading ${language.name}…',
      SourceReady(:final language) => language.name,
      SourceUnsupported(:final tag) => "'$tag' can't be translated",
      SourceNotFound() => 'No supported text found',
      SourceDownloadFailed(:final language) =>
        "${language.name} didn't download",
    };
    expect(sourceLabel(), 'Looking for text…');
  });

  test('the entry library exposes every exception subtype', () {
    final errors = <LiveTranslateException>[
      const CameraPermissionDenied(),
      const CameraUnavailable(),
      const ModelNotDownloaded(TranslateLanguage.hindi),
      const UnsupportedLanguagePair(
        source: 'xx',
        target: TranslateLanguage.english,
      ),
      PipelineFailure(Exception('x')),
    ];
    expect(errors, everyElement(isA<Exception>()));
  });

  test('the entry library exposes TranslationModels', () {
    expect(TranslationModels.new, isA<TranslationModels Function()>());
  });

  test('the entry library exposes the view, controller and state', () {
    const view = LiveTranslateView(targetLanguage: TranslateLanguage.english);
    expect(view.targetLanguage, TranslateLanguage.english);
    final controller = LiveTranslateController();
    addTearDown(controller.dispose);
    expect(controller.state, LiveTranslateState.initializing);
    expect(controller.targetLanguage, isNull);
    expect(LiveTranslateState.values, hasLength(4));
  });

  test('the entry library exposes the view hooks', () {
    Widget overlay(BuildContext context, List<TranslatedParagraph> lines) =>
        const SizedBox();
    final OverlayBuilder builder = overlay;
    void report(List<TranslatedParagraph> lines) {}
    final view = LiveTranslateView(
      overlayBuilder: builder,
      onParagraphsChanged: report,
      onFrozen: report,
      placeholderBuilder: (context) => const SizedBox(),
    );
    expect(view.overlayBuilder, same(builder));
    expect(view.onParagraphsChanged, isNotNull);
    expect(view.onFrozen, isNotNull);
    expect(view.placeholderBuilder, isNotNull);
  });

  test('the entry library exposes the metrics and the HUD', () async {
    const metrics = PipelineMetrics(
      recognition: Duration(milliseconds: 120),
      translation: Duration(milliseconds: 80),
      sampling: Duration(milliseconds: 10),
      total: Duration(milliseconds: 214),
      paragraphs: 1,
      frozen: false,
    );
    expect(metrics.total.inMilliseconds, 214);
    final controller = LiveTranslateController();
    final Stream<PipelineMetrics> stream = controller.metrics;
    controller.dispose();
    expect(await stream.isEmpty, isTrue);
    const view = LiveTranslateView(showDebugHud: true);
    expect(view.showDebugHud, isTrue);
  });

  test('the entry library re-exports the dependency types it uses', () {
    expect(TranslateLanguage.english.name, 'english');
    expect(ResolutionPreset.medium.name, 'medium');
  });
}
