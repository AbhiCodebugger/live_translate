import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/controller/live_translate_controller.dart';
import 'package:live_translate/src/controller/live_translate_state.dart';
import 'package:live_translate/src/models/source_status.dart';
import 'package:live_translate/src/models/text_script.dart';
import 'package:live_translate/src/models/translated_paragraph.dart';
import 'package:live_translate/src/pipeline/pipeline_metrics.dart';

final class _Host implements ControllerHost {
  final calls = <String>[];

  @override
  Future<void> freeze() async => calls.add('freeze');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> setTargetLanguage(TranslateLanguage language) async =>
      calls.add('target ${language.name}');

  @override
  Future<void> setScripts(Set<TextScript> scripts) async =>
      calls.add('scripts ${scripts.map((s) => s.name).join(',')}');

  @override
  Future<void> setSourceLanguages(Set<TranslateLanguage>? languages) async =>
      calls.add('sources ${languages?.map((l) => l.name).join(',')}');

  @override
  Future<void> setTorch(bool on) async => calls.add('torch $on');
}

const _line = TranslatedParagraph(
  id: 't1',
  sourceText: 'निकास',
  translatedText: 'Exit',
  rect: Rect.fromLTRB(17.5, 125, 142.5, 162.5),
);

Future<void> _callEverything(LiveTranslateController controller) async {
  await controller.freeze();
  await controller.resume();
  await controller.setTargetLanguage(TranslateLanguage.french);
  await controller.setScripts({TextScript.latin, TextScript.devanagari});
  await controller.setSourceLanguages({TranslateLanguage.hindi});
  await controller.setSourceLanguages(null);
  await controller.setTorch(true);
}

void main() {
  late LiveTranslateController controller;
  late _Host host;
  late int notifications;

  setUp(() {
    controller = LiveTranslateController();
    host = _Host();
    notifications = 0;
    controller.addListener(() => notifications++);
  });

  test('an unattached controller is initializing, empty and inert', () async {
    expect(controller.state, LiveTranslateState.initializing);
    expect(controller.paragraphs, isEmpty);
    expect(controller.targetLanguage, isNull);
    await _callEverything(controller);
    expect(notifications, 0);
  });

  test('an attached controller forwards every call', () async {
    attachController(controller, host);
    await _callEverything(controller);
    expect(host.calls, [
      'freeze',
      'resume',
      'target french',
      'scripts latin,devanagari',
      'sources hindi',
      'sources null',
      'torch true',
    ]);
  });

  group('source status', () {
    void publish(SourceStatus status) => publishToController(
      controller,
      state: LiveTranslateState.running,
      paragraphs: const [],
      target: TranslateLanguage.english,
      sourceStatus: status,
    );

    test('is searching when not attached', () {
      expect(controller.sourceStatus, const SourceSearching());
    });

    test('a guessed language notifies', () {
      attachController(controller, host);
      publish(const SourceGuessed(TranslateLanguage.spanish));
      expect(
        controller.sourceStatus,
        const SourceGuessed(TranslateLanguage.spanish),
      );
      expect(notifications, 1);
    });

    test('an unchanged status does not notify', () {
      attachController(controller, host);
      publish(const SourceReady(TranslateLanguage.spanish));
      publish(const SourceReady(TranslateLanguage.spanish));
      expect(notifications, 1);
    });

    test('detaching goes back to searching', () {
      attachController(controller, host);
      publish(const SourceReady(TranslateLanguage.spanish));
      detachController(controller, host);
      expect(controller.sourceStatus, const SourceSearching());
    });
  });

  test('publishing a change notifies once', () {
    attachController(controller, host);
    publishToController(
      controller,
      state: LiveTranslateState.running,
      paragraphs: const [_line],
      target: TranslateLanguage.english,
    );
    expect(controller.state, LiveTranslateState.running);
    expect(controller.paragraphs, const [_line]);
    expect(controller.targetLanguage, TranslateLanguage.english);
    expect(notifications, 1);
  });

  test('publishing a new target language notifies once', () {
    attachController(controller, host);
    publishToController(
      controller,
      state: LiveTranslateState.running,
      paragraphs: const [],
      target: TranslateLanguage.english,
    );
    publishToController(
      controller,
      state: LiveTranslateState.running,
      paragraphs: const [],
      target: TranslateLanguage.french,
    );
    expect(controller.targetLanguage, TranslateLanguage.french);
    expect(notifications, 2);
  });

  test('publishing equal values does not notify', () {
    attachController(controller, host);
    publishToController(
      controller,
      state: LiveTranslateState.running,
      paragraphs: const [_line],
      target: TranslateLanguage.english,
    );
    publishToController(
      controller,
      state: LiveTranslateState.running,
      paragraphs: [_line],
      target: TranslateLanguage.english,
    );
    expect(notifications, 1);
  });

  test('the published lines cannot be modified', () {
    publishToController(
      controller,
      state: LiveTranslateState.running,
      paragraphs: [_line],
      target: TranslateLanguage.english,
    );
    expect(() => controller.paragraphs.add(_line), throwsUnsupportedError);
  });

  test('a controller drives only one view at a time', () {
    attachController(controller, host);
    expect(() => attachController(controller, _Host()), throwsAssertionError);
    // Re-attaching the same host is fine.
    attachController(controller, host);
  });

  test('after detaching, calls are ignored and the state resets', () async {
    attachController(controller, host);
    publishToController(
      controller,
      state: LiveTranslateState.frozen,
      paragraphs: const [_line],
      target: TranslateLanguage.english,
    );
    detachController(controller, host);
    await _callEverything(controller);
    expect(host.calls, isEmpty);
    expect(controller.state, LiveTranslateState.initializing);
    expect(controller.paragraphs, isEmpty);
    expect(controller.targetLanguage, isNull);
  });

  test('detaching from another host does nothing', () async {
    attachController(controller, host);
    detachController(controller, _Host());
    await controller.freeze();
    expect(host.calls, ['freeze']);
  });

  group('metrics', () {
    const metrics = PipelineMetrics(
      recognition: Duration(milliseconds: 120),
      translation: Duration(milliseconds: 80),
      sampling: Duration(milliseconds: 10),
      total: Duration(milliseconds: 214),
      paragraphs: 1,
      frozen: false,
    );

    test('every listener receives the same metrics', () async {
      attachController(controller, host);
      final first = <PipelineMetrics>[];
      final second = <PipelineMetrics>[];
      controller.metrics.listen(first.add);
      controller.metrics.listen(second.add);
      publishMetrics(controller, metrics);
      await pumpEventQueue();
      expect(first, [metrics]);
      expect(second, [metrics]);
    });

    test('an unattached controller emits nothing', () async {
      final received = <PipelineMetrics>[];
      controller.metrics.listen(received.add);
      publishMetrics(controller, metrics);
      await pumpEventQueue();
      expect(received, isEmpty);
    });

    test('disposing closes the stream', () async {
      final own = LiveTranslateController();
      var done = false;
      own.metrics.listen(null, onDone: () => done = true);
      attachController(own, host);
      own.dispose();
      publishMetrics(own, metrics); // Ignored once closed.
      await pumpEventQueue();
      expect(done, isTrue);
    });
  });
}
