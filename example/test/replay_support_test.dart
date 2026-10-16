import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

import 'package:live_translate/live_translate.dart';

import '../integration_test/replay/frame.dart';
import '../integration_test/replay/manifest.dart';
import '../integration_test/replay/matching.dart';

const _manifest = '''
{
  "frames": [
    {
      "file": "hi_exit_sign.jpg",
      "note": "Red EXIT sign",
      "target": "en",
      "scripts": ["latin", "devanagari"],
      "sourceLanguages": null,
      "expect": [
        { "source": "निकास", "language": "hi", "translation": ["exit"] }
      ]
    },
    {
      "file": "es_menu.jpg",
      "target": "en",
      "scripts": ["latin"],
      "sourceLanguages": ["es"],
      "expect": [{ "source": "Salida", "language": "es" }]
    }
  ]
}
''';

ReadParagraphText _read(String source, String? language, String translated) =>
    (sourceText: source, sourceLanguage: language, translatedText: translated);

/// A PNG [width] × [height] whose left half is red and right half white.
Future<Uint8List> _halves(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    )
    ..drawRect(
      ui.Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildReplayFrame', () {
    test('makes NV21 on Android', () async {
      final frame = await buildReplayFrame(
        await _halves(4, 2),
        TargetPlatform.android,
      );
      final image = frame.image;
      expect(image.format.raw, nv21Raw);
      expect((image.width, image.height), (4, 2));
      final plane = image.planes.single;
      expect(plane.bytesPerRow, 4);
      // Luma: red is 76, white 255.
      expect(plane.bytes.sublist(0, 8), [76, 76, 255, 255, 76, 76, 255, 255]);
      // Chroma, V then U per 2 × 2 block: red, then white.
      expect(plane.bytes.sublist(8), [255, 85, 128, 128]);
    });

    test('makes BGRA on iOS', () async {
      final frame = await buildReplayFrame(
        await _halves(4, 2),
        TargetPlatform.iOS,
      );
      final image = frame.image;
      expect(image.format.raw, bgraRaw);
      final plane = image.planes.single;
      expect(plane.bytesPerRow, 16);
      expect(plane.bytes.sublist(0, 4), [0, 0, 255, 255]);
      expect(plane.bytes.sublist(8, 12), [255, 255, 255, 255]);
    });

    test('crops odd sizes to even', () async {
      final frame = await buildReplayFrame(
        await _halves(5, 3),
        TargetPlatform.android,
      );
      expect((frame.image.width, frame.image.height), (4, 2));
      expect(frame.image.planes.single.bytes, hasLength(4 * 2 * 3 ~/ 2));
    });

    test('is upright', () async {
      final frame = await buildReplayFrame(
        await _halves(4, 2),
        TargetPlatform.android,
      );
      expect(frame.rotation.name, 'deg0');
    });
  });

  group('ReplayManifest', () {
    test('parses frames and their expectations', () {
      final manifest = ReplayManifest.parse(_manifest);
      final [sign, menu] = manifest.frames;
      expect(sign.file, 'hi_exit_sign.jpg');
      expect(sign.note, 'Red EXIT sign');
      expect(sign.target, TranslateLanguage.english);
      expect(sign.scripts, {TextScript.latin, TextScript.devanagari});
      expect(sign.sourceLanguages, isNull);
      expect(sign.expect.single.source, 'निकास');
      expect(sign.expect.single.language, 'hi');
      expect(sign.expect.single.translation, ['exit']);
      expect(menu.sourceLanguages, {TranslateLanguage.spanish});
      expect(menu.expect.single.translation, isEmpty);
      expect(manifest.languages, {
        TranslateLanguage.english,
        TranslateLanguage.hindi,
        TranslateLanguage.spanish,
      });
    });

    test('names the frame with an unknown language', () {
      expect(
        () => ReplayManifest.parse(_manifest.replaceFirst('"hi"', '"xx"')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('hi_exit_sign.jpg'), contains('"xx"')),
          ),
        ),
      );
    });

    test('the shipped frames.json parses and names existing photos', () {
      const folder = 'assets/replay_frames';
      final manifest = ReplayManifest.parse(
        File('$folder/frames.json').readAsStringSync(),
      );
      expect(manifest.frames, isNotEmpty);
      for (final frame in manifest.frames) {
        expect(
          File('$folder/${frame.file}').existsSync(),
          isTrue,
          reason: frame.file,
        );
      }
      final bytes = Directory(folder).listSync().whereType<File>().fold<int>(
        0,
        (sum, file) => sum + file.lengthSync(),
      );
      expect(bytes, lessThanOrEqualTo(3 * 1024 * 1024));
    });

    test('rejects an unknown script', () {
      expect(
        () =>
            ReplayManifest.parse(_manifest.replaceFirst('"latin"]', '"han"]')),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('es_menu.jpg'),
          ),
        ),
      );
    });
  });

  group('matching', () {
    final frame = ReplayManifest.parse(_manifest).frames.first;
    final expectation = frame.expect.single;

    test('a fragment matches despite punctuation, case and spacing', () {
      expect(
        normalize('  "Salida",  de\nEMERGENCIA! '),
        'salida de emergencia',
      );
      expect(satisfies(expectation, _read('निकास  —', 'hi', 'Exit')), isTrue);
    });

    test('the wrong language fails', () {
      expect(satisfies(expectation, _read('निकास', 'mr', 'Exit')), isFalse);
    });

    test('a translation equal to its source fails', () {
      final any = ReplayManifest.parse(_manifest).frames.last.expect.single;
      expect(satisfies(any, _read('Salida', 'es', 'Salida.')), isFalse);
      expect(satisfies(any, _read('Salida', 'es', 'Exit')), isTrue);
    });

    test('a keyword must appear in the translation', () {
      expect(satisfies(expectation, _read('निकास', 'hi', 'Way out')), isFalse);
      expect(satisfies(expectation, _read('निकास', 'hi', 'EXIT here')), isTrue);
    });

    test('a failure lists every paragraph read', () {
      final message = failures(frame, [
        _read('प्रवेश', 'hi', 'Entrance'),
        _read('Platform 2', 'en', ''),
      ])!;
      expect(message, contains('hi_exit_sign.jpg (Red EXIT sign)'));
      expect(message, contains('"निकास" [hi]'));
      expect(message, contains('read 2 paragraphs'));
      expect(message, contains('"प्रवेश" [hi] → "Entrance"'));
      expect(message, contains('"Platform 2" [en] → ""'));
    });

    test('no failure when every expectation is met', () {
      expect(failures(frame, [_read('निकास', 'hi', 'Exit')]), isNull);
    });
  });
}
