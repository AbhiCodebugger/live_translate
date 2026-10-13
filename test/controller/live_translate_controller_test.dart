import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/controller/live_translate_controller.dart';
import 'package:live_translate/src/controller/live_translate_state.dart';
import 'package:live_translate/src/models/text_script.dart';
import 'package:live_translate/src/models/translated_line.dart';

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
  Future<void> setTorch(bool on) async => calls.add('torch $on');
}

const _line = TranslatedLine(
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
    expect(controller.lines, isEmpty);
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
      'torch true',
    ]);
  });

  test('publishing a change notifies once', () {
    attachController(controller, host);
    publishToController(
      controller,
      state: LiveTranslateState.running,
      lines: const [_line],
      target: TranslateLanguage.english,
    );
    expect(controller.state, LiveTranslateState.running);
    expect(controller.lines, const [_line]);
    expect(controller.targetLanguage, TranslateLanguage.english);
    expect(notifications, 1);
  });

  test('publishing a new target language notifies once', () {
    attachController(controller, host);
    publishToController(
      controller,
      state: LiveTranslateState.running,
      lines: const [],
      target: TranslateLanguage.english,
    );
    publishToController(
      controller,
      state: LiveTranslateState.running,
      lines: const [],
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
      lines: const [_line],
      target: TranslateLanguage.english,
    );
    publishToController(
      controller,
      state: LiveTranslateState.running,
      lines: [_line],
      target: TranslateLanguage.english,
    );
    expect(notifications, 1);
  });

  test('the published lines cannot be modified', () {
    publishToController(
      controller,
      state: LiveTranslateState.running,
      lines: [_line],
      target: TranslateLanguage.english,
    );
    expect(() => controller.lines.add(_line), throwsUnsupportedError);
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
      lines: const [_line],
      target: TranslateLanguage.english,
    );
    detachController(controller, host);
    await _callEverything(controller);
    expect(host.calls, isEmpty);
    expect(controller.state, LiveTranslateState.initializing);
    expect(controller.lines, isEmpty);
    expect(controller.targetLanguage, isNull);
  });

  test('detaching from another host does nothing', () async {
    attachController(controller, host);
    detachController(controller, _Host());
    await controller.freeze();
    expect(host.calls, ['freeze']);
  });
}
