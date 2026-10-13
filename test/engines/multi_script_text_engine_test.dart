import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:live_translate/src/engines/multi_script_text_engine.dart';
import 'package:live_translate/src/engines/text_engine.dart';
import 'package:live_translate/src/models/text_script.dart';

import '../support/fakes.dart';

final _image = InputImage.fromBytes(
  bytes: Uint8List(4),
  metadata: InputImageMetadata(
    size: const Size(1, 1),
    rotation: InputImageRotation.rotation0deg,
    format: InputImageFormat.bgra8888,
    bytesPerRow: 4,
  ),
);

RecognizedLine line(
  String text, [
  Rect box = const Rect.fromLTWH(0, 0, 10, 10),
]) => RecognizedLine(text: text, box: box);

void main() {
  late FakeTextEngine latin;
  late FakeTextEngine devanagari;
  late MultiScriptTextEngine engine;

  setUp(() {
    latin = FakeTextEngine();
    devanagari = FakeTextEngine();
    engine = MultiScriptTextEngine({
      // Deliberately out of order: results follow TextScript order.
      TextScript.devanagari: devanagari,
      TextScript.latin: latin,
    });
  });

  test('every read uses every script', () async {
    latin.lines = [line('EXIT', const Rect.fromLTRB(0, 50, 60, 70))];
    devanagari.lines = [line('निकास')];
    final result = await engine.recognize(_image);
    expect(result.map((l) => l.text), ['EXIT', 'निकास']);
    expect(latin.calls, 1);
    expect(devanagari.calls, 1);
  });

  test('each read shows only what that read found', () async {
    latin.lines = [line('EXIT')];
    await engine.recognize(_image);
    latin.lines = const [];
    final result = await engine.recognize(_image);
    expect(result, isEmpty);
  });

  test('drops lines without enough letters', () async {
    latin.lines = [
      line('2026'),
      line('Platform 2'),
      line('A'),
      line('No entry'),
    ];
    final result = await engine.recognize(_image);
    expect(result.map((l) => l.text), ['Platform 2', 'No entry']);
  });

  test('a single script reads alone', () async {
    final only = MultiScriptTextEngine({TextScript.latin: latin});
    latin.lines = [line('EXIT')];
    final result = await only.recognize(_image);
    expect(latin.calls, 1);
    expect(result.map((l) => l.text), ['EXIT']);
  });

  test('closes every engine once and refuses work afterwards', () async {
    await engine.close();
    await engine.close();
    expect(latin.closes, 1);
    expect(devanagari.closes, 1);
    await expectLater(engine.recognize(_image), throwsStateError);
  });

  group('overlapping Latin readings', () {
    const hindiBox = Rect.fromLTRB(0, 0, 100, 20);

    Future<List<String>> readOnce() async =>
        (await engine.recognize(_image)).map((l) => l.text).toList();

    test('gibberish over a Hindi line is dropped', () async {
      latin.lines = [line('Tea Ho', const Rect.fromLTRB(5, 2, 95, 18))];
      devanagari.lines = [line('नमस्ते', hindiBox)];
      expect(await readOnce(), ['नमस्ते']);
    });

    test('a separate English line is kept', () async {
      latin.lines = [line('EXIT', const Rect.fromLTRB(0, 50, 60, 70))];
      devanagari.lines = [line('नमस्ते', hindiBox)];
      expect(await readOnce(), ['EXIT', 'नमस्ते']);
    });

    test('a small overlap is kept', () async {
      // Only the left 40% of the Latin box is covered.
      latin.lines = [line('Open now', const Rect.fromLTRB(60, 0, 160, 20))];
      devanagari.lines = [line('नमस्ते', hindiBox)];
      expect(await readOnce(), ['Open now', 'नमस्ते']);
    });

    test('exactly half covered is dropped', () async {
      latin.lines = [line('Tea Ho', const Rect.fromLTRB(50, 0, 150, 20))];
      devanagari.lines = [line('नमस्ते', hindiBox)];
      expect(await readOnce(), ['नमस्ते']);
    });

    test('Latin only drops nothing for overlap', () async {
      final only = MultiScriptTextEngine({TextScript.latin: latin});
      latin.lines = [
        line('Open now', hindiBox),
        line('Closed', const Rect.fromLTRB(5, 2, 95, 18)),
      ];
      final result = await only.recognize(_image);
      expect(result.map((l) => l.text), ['Open now', 'Closed']);
    });
  });

  group("each recognizer keeps only its own script's lines", () {
    Future<List<String>> readOnce() async =>
        (await engine.recognize(_image)).map((l) => l.text).toList();

    test('Latin text read by the Devanagari recognizer is dropped', () async {
      devanagari.lines = [line('Elememte chan na')];
      expect(await readOnce(), isEmpty);
    });

    test('a stray Devanagari letter is dropped', () async {
      devanagari.lines = [line('Lorem क ipsum')];
      expect(await readOnce(), isEmpty);
    });

    test('a mixed Devanagari line is kept', () async {
      devanagari.lines = [line('दवा 500mg')];
      expect(await readOnce(), ['दवा 500mg']);
    });

    test('a Latin page keeps only the Latin reading', () async {
      latin.lines = [
        line("Pourquoi l'utiliser?", const Rect.fromLTRB(0, 100, 200, 120)),
      ];
      // The Devanagari reader's copy, a frame later and slightly lower.
      devanagari.lines = [
        line("Pourquoi l'utiliscr?", const Rect.fromLTRB(0, 125, 200, 145)),
      ];
      expect(await readOnce(), ["Pourquoi l'utiliser?"]);
    });
  });

  group('the reading in the text\'s own script wins', () {
    const place = Rect.fromLTRB(0, 0, 200, 20);

    test('a mostly-Latin Devanagari misreading gives way', () async {
      latin.lines = [line('étudiant tous les usages', place)];
      devanagari.lines = [line('étudiant तस les usages', place)];
      final result = await engine.recognize(_image);
      expect(result.map((l) => l.text), ['étudiant tous les usages']);
    });

    test('a misreading three-quarters over a Latin line gives way', () async {
      latin.lines = [
        line('Pourquoi utiliser', const Rect.fromLTRB(0, 0, 200, 20)),
      ];
      devanagari.lines = [
        line('Pourquoi कख utiliser', const Rect.fromLTRB(0, 5, 200, 25)),
      ];
      final result = await engine.recognize(_image);
      expect(result.map((l) => l.text), ['Pourquoi utiliser']);
    });

    test('a mixed line with as many Devanagari letters wins', () async {
      latin.lines = [line('Tea 500mg', place)];
      devanagari.lines = [line('दवा 500mg', place)];
      final result = await engine.recognize(_image);
      expect(result.map((l) => l.text), ['दवा 500mg']);
    });
  });

  group('merging', () {
    test('keeps paragraphs of different scripts apart', () async {
      latin.lines = [
        const RecognizedLine(text: 'EXIT', box: Rect.fromLTRB(0, 50, 60, 70)),
      ];
      devanagari.lines = [
        const RecognizedLine(text: 'निकास', box: Rect.fromLTRB(0, 0, 60, 20)),
      ];
      final result = await engine.recognize(_image);
      expect(result.map((l) => l.paragraph).toSet(), hasLength(2));
    });

    test('applies the overlap and own-script filters', () async {
      latin.lines = [line('Tea Ho', const Rect.fromLTRB(5, 2, 95, 18))];
      devanagari.lines = [
        line('नमस्ते', const Rect.fromLTRB(0, 0, 100, 20)),
        line('Elememte chan na', const Rect.fromLTRB(0, 40, 100, 60)),
      ];
      final result = await engine.recognize(_image);
      expect(result.map((l) => l.text), ['नमस्ते']);
    });
  });
}
