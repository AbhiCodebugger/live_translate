import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:live_translate/src/engines/mlkit/mlkit_text_engine.dart';
import 'package:live_translate/src/engines/multi_script_text_engine.dart';
import 'package:live_translate/src/engines/text_engine.dart';
import 'package:live_translate/src/models/text_script.dart';

final class _FakeRecognizer implements TextRecognizer {
  _FakeRecognizer(this.result);

  final RecognizedText result;
  int processed = 0;
  int closed = 0;

  @override
  TextRecognitionScript get script => TextRecognitionScript.latin;

  @override
  String get id => 'fake';

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async {
    processed++;
    return result;
  }

  @override
  Future<void> close() async => closed++;
}

TextLine _line(String text, Rect box, {double? confidence}) => TextLine(
  text: text,
  elements: const [],
  boundingBox: box,
  recognizedLanguages: const [],
  cornerPoints: const [],
  confidence: confidence,
  angle: null,
);

TextBlock _block(List<TextLine> lines) => TextBlock(
  text: lines.map((l) => l.text).join('\n'),
  lines: lines,
  boundingBox: lines.first.boundingBox,
  recognizedLanguages: const [],
  cornerPoints: const [],
);

final _image = InputImage.fromBytes(
  bytes: Uint8List(4),
  metadata: InputImageMetadata(
    size: const Size(1, 1),
    rotation: InputImageRotation.rotation0deg,
    format: InputImageFormat.bgra8888,
    bytesPerRow: 4,
  ),
);

void main() {
  late List<_FakeRecognizer> created;
  late List<TextRecognitionScript> scripts;

  MlKitTextEngine engine(
    RecognizedText result, {
    TextScript script = TextScript.latin,
  }) {
    created = [];
    scripts = [];
    return MlKitTextEngine(
      script: script,
      createRecognizer: (recognitionScript) {
        scripts.add(recognitionScript);
        final recognizer = _FakeRecognizer(result);
        created.add(recognizer);
        return recognizer;
      },
    );
  }

  final twoBlocks = RecognizedText(
    text: '',
    blocks: [
      _block([
        _line('EXIT', const Rect.fromLTRB(10, 10, 60, 30)),
        _line('Platform 2', const Rect.fromLTRB(10, 40, 120, 60)),
      ]),
      _block([_line('Open', const Rect.fromLTRB(200, 10, 250, 30))]),
    ],
  );

  test('both scripts create their recognizers on the first read', () async {
    final created = <TextRecognitionScript>[];
    MlKitTextEngine reader(TextScript script) => MlKitTextEngine(
      script: script,
      createRecognizer: (recognitionScript) {
        created.add(recognitionScript);
        return _FakeRecognizer(RecognizedText(text: '', blocks: const []));
      },
    );
    final both = MultiScriptTextEngine({
      TextScript.latin: reader(TextScript.latin),
      TextScript.devanagari: reader(TextScript.devanagari),
    });
    expect(created, isEmpty);
    await both.recognize(_image);
    expect(created, hasLength(2));
    await both.close();
  });

  test('creates no recognizer until the first frame', () async {
    final e = engine(twoBlocks);
    expect(created, isEmpty);
    await e.close();
    expect(created, isEmpty);
  });

  test('flattens blocks into lines with text and boxes', () async {
    final lines = await engine(twoBlocks).recognize(_image);
    expect(lines, const [
      RecognizedLine(text: 'EXIT', box: Rect.fromLTRB(10, 10, 60, 30)),
      RecognizedLine(text: 'Platform 2', box: Rect.fromLTRB(10, 40, 120, 60)),
      RecognizedLine(
        text: 'Open',
        box: Rect.fromLTRB(200, 10, 250, 30),
        paragraph: 1,
      ),
    ]);
  });

  test("gives each block's lines one paragraph, in reading order", () async {
    final heading = RecognizedText(
      text: '',
      blocks: [
        _block([_line('Pourquoi', const Rect.fromLTRB(10, 10, 90, 30))]),
        _block([
          _line('On sait depuis', const Rect.fromLTRB(10, 40, 200, 60)),
          _line('longtemps', const Rect.fromLTRB(10, 64, 120, 84)),
        ]),
      ],
    );
    final lines = await engine(heading).recognize(_image);
    expect(lines.map((l) => (l.text, l.paragraph)), [
      ('Pourquoi', 0),
      ('On sait depuis', 1),
      ('longtemps', 1),
    ]);
  });

  test('drops lines the recognizer is unsure of', () async {
    final mixed = RecognizedText(
      text: '',
      blocks: [
        _block([
          _line(
            'Il nv a ras de minitre',
            const Rect.fromLTRB(10, 10, 200, 30),
            confidence: 0.3,
          ),
          _line(
            "Pourquoi l'utiliser ?",
            const Rect.fromLTRB(10, 40, 200, 60),
            confidence: 0.9,
          ),
          _line('Lorem ipsum', const Rect.fromLTRB(10, 70, 200, 90)),
        ]),
      ],
    );
    final lines = await engine(mixed).recognize(_image);
    expect(lines.map((l) => l.text), ["Pourquoi l'utiliser ?", 'Lorem ipsum']);
  });

  test('returns an empty list for a frame with no text', () async {
    final lines = await engine(
      RecognizedText(text: '', blocks: const []),
    ).recognize(_image);
    expect(lines, isEmpty);
  });

  test('reuses one recognizer and closes it exactly once', () async {
    final e = engine(twoBlocks);
    await e.recognize(_image);
    await e.recognize(_image);
    await e.close();
    await e.close();
    expect(created, hasLength(1));
    expect(created.single.processed, 2);
    expect(created.single.closed, 1);
  });

  test('reads Latin by default', () async {
    final e = MlKitTextEngine(
      createRecognizer: (_) => throw UnimplementedError(),
    );
    expect(e.script, TextScript.latin);
  });

  test('creates the recognizer for its script', () async {
    await engine(twoBlocks, script: TextScript.devanagari).recognize(_image);
    expect(scripts, [TextRecognitionScript.devanagiri]);
  });

  test('throws when used after close', () async {
    final e = engine(twoBlocks);
    await e.close();
    await expectLater(e.recognize(_image), throwsStateError);
    expect(created, isEmpty);
  });
}
