// Replays saved photos through the real pipeline: the camera format
// converter, ML Kit recognition, language ID and translation, and colour
// sampling. Needs a real device.
//
//   flutter test integration_test/replay_test.dart -d <device>
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/replay_test.dart -d <device>
//
// The second writes each frame's timings to
// build/integration_response_data.json.
// ignore_for_file: implementation_imports, avoid_print

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_translate/live_translate.dart';
import 'package:live_translate/src/pipeline/line_translator.dart';
import 'package:live_translate/src/pipeline/pipeline.dart';
import 'package:live_translate/src/still/read_result.dart';
import 'package:live_translate/src/view/live_translate_view.dart'
    show mlKitEngines;

import 'replay/frame.dart';
import 'replay/manifest.dart';
import 'replay/matching.dart';

const _folder = 'assets/replay_frames';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'replays every frame',
    timeout: const Timeout(Duration(minutes: 30)),
    (tester) async {
      final manifest = ReplayManifest.parse(
        await rootBundle.loadString('$_folder/frames.json'),
      );
      final downloads = await _downloadModels(manifest.languages);

      final clock = Stopwatch()..start();
      final epoch = DateTime.now();
      DateTime now() => epoch.add(clock.elapsed);

      final results = <Map<String, Object?>>[];
      final problems = <String>[];
      for (final spec in manifest.frames) {
        final photo = await rootBundle.load('$_folder/${spec.file}');
        final frame = await buildReplayFrame(
          photo.buffer.asUint8List(),
          defaultTargetPlatform,
        );
        final engines = mlKitEngines();
        final text = engines.text(spec.scripts);
        final language = engines.language();
        final translate = engines.translate();
        final reported = <LiveTranslateException>[];
        final pipeline = Pipeline(
          textEngine: text,
          createTranslator: (onError, onModelReady) => LineTranslator(
            languageEngine: language,
            translateEngine: translate,
            modelStore: engines.models,
            onError: onError,
            onModelReady: onModelReady,
          ),
          target: spec.target,
          sourceLanguages: spec.sourceLanguages,
          now: now,
        );
        final subscription = pipeline.errors.listen(reported.add);
        try {
          // Cold: the first read after the engines are built. Warm: the same
          // frame again, as a held view reads after a small pan.
          final cold = await pipeline.read(frame);
          final warm = await pipeline.read(frame);
          if (cold == null || warm == null) {
            problems.add('${spec.file}: the frame format was not readable');
            continue;
          }
          final read = [
            for (final p in warm.paragraphs)
              (
                sourceText: p.sourceText,
                sourceLanguage: p.sourceLanguage,
                translatedText: p.translatedText,
              ),
          ];
          final failure = failures(spec, read);
          if (failure != null) {
            problems.add(
              [
                failure,
                if (warm.untranslatedLanguages.isNotEmpty)
                  'untranslated languages: ${warm.untranslatedLanguages}',
                for (final error in reported) 'reported: $error',
              ].join('\n'),
            );
          }
          results.add({
            'file': spec.file,
            'passed': failure == null,
            'paragraphs': warm.paragraphs.length,
            'cold': _timings(cold),
            'warm': _timings(warm),
          });
        } finally {
          await subscription.cancel();
          await pipeline.dispose();
          await Future.wait([
            text.close(),
            language.close(),
            translate.close(),
          ]);
        }
      }

      _printTable(results);
      binding.reportData = {
        'platform': defaultTargetPlatform.name,
        'os': Platform.operatingSystemVersion,
        'modelDownloadsMs': downloads,
        'frames': results,
      };
      expect(problems, isEmpty, reason: problems.join('\n\n'));
    },
  );
}

/// Downloads each missing model in [languages], returning how long each
/// took in milliseconds.
Future<Map<String, int>> _downloadModels(
  Set<TranslateLanguage> languages,
) async {
  final models = TranslationModels();
  final took = <String, int>{};
  for (final language in languages) {
    if (await models.isDownloaded(language)) continue;
    final watch = Stopwatch()..start();
    await models
        .download(language, wifiOnly: false)
        .timeout(const Duration(minutes: 5));
    took[language.name] = watch.elapsedMilliseconds;
    print('Downloaded ${language.name} in ${watch.elapsedMilliseconds} ms');
  }
  return took;
}

Map<String, int> _timings(ReadResult result) => {
  'recognitionMs': result.timings.recognition.inMilliseconds,
  'translationMs': result.timings.translation.inMilliseconds,
  'samplingMs': result.timings.sampling.inMilliseconds,
  'totalMs': result.timings.total.inMilliseconds,
};

void _printTable(List<Map<String, Object?>> results) {
  String row(List<Object?> cells) => [
    cells.first.toString().padRight(28),
    for (final cell in cells.skip(1)) cell.toString().padLeft(7),
  ].join(' ');
  print(
    row(['frame', 'ok', 'paras', 'cold', 'warm', 'ocr', 'transl', 'colour']),
  );
  for (final r in results) {
    final cold = r['cold']! as Map<String, int>;
    final warm = r['warm']! as Map<String, int>;
    print(
      row([
        r['file'],
        r['passed']! as bool ? 'yes' : 'NO',
        r['paragraphs'],
        cold['totalMs'],
        warm['totalMs'],
        cold['recognitionMs'],
        cold['translationMs'],
        cold['samplingMs'],
      ]),
    );
  }
  print('Times in ms. ocr, transl and colour are from the cold read.');
}
