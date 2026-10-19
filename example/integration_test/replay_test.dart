// Replays saved photos through the real pipeline: the camera format
// converter, ML Kit recognition, language ID and translation, and colour
// sampling. Needs a real device.
//
//   flutter test integration_test/replay_test.dart -d <device>
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/replay_test.dart -d <device>
//
// The second, in profile mode, gives timings worth comparing. It writes
// them to build/integration_response_data.json:
//
//   frames[].cold    the first read after the engines are built
//   frames[].warm    the median and max of 5 more reads of the full photo
//   frames[].stream  the same for the photo scaled to the camera's stream
//                    size (long side 720 on Android, 640 on iOS), and
//                    whether its expectations would pass
//   summary          the median across frames of cold, warm.median and
//                    stream.median
//
// Each timing has recognitionMs, translationMs, samplingMs and totalMs.
// Only the full photo's expectations fail the test.
// ignore_for_file: implementation_imports, avoid_print

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

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

/// Warm reads per photo and size, after the cold read.
const _warmReads = 5;

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
        final photo = (await rootBundle.load(
          '$_folder/${spec.file}',
        )).buffer.asUint8List();
        final frame = await buildReplayFrame(photo, defaultTargetPlatform);
        final streamFrame = await buildReplayFrame(
          photo,
          defaultTargetPlatform,
          longSide: streamLongSide(defaultTargetPlatform),
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
          // frame again, as a held view reads after a small pan. Stream: the
          // frame at the size the camera streams.
          final cold = await pipeline.read(frame);
          final warmReads = [
            for (var i = 0; i < _warmReads; i++) await pipeline.read(frame),
          ];
          final streamReads = [
            for (var i = 0; i < _warmReads; i++)
              await pipeline.read(streamFrame),
          ];
          if (cold == null ||
              warmReads.contains(null) ||
              streamReads.contains(null)) {
            problems.add('${spec.file}: the frame format was not readable');
            continue;
          }
          final warm = warmReads.last!;
          final failure = failures(spec, _texts(warm));
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
            'failure': ?failure,
            'paragraphs': warm.paragraphs.length,
            'cold': _timings(cold),
            'warm': _stats([for (final r in warmReads) r!]),
            'stream': {
              ..._stats([for (final r in streamReads) r!]),
              'passed': failures(spec, _texts(streamReads.last!)) == null,
              'paragraphs': streamReads.last!.paragraphs.length,
            },
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

      final summary = _summary(results);
      _printTable(results, summary);
      binding.reportData = {
        'platform': defaultTargetPlatform.name,
        'os': Platform.operatingSystemVersion,
        'modelDownloadsMs': downloads,
        'warmReads': _warmReads,
        'frames': results,
        'summary': summary,
      };
      expect(problems, isEmpty, reason: problems.join('\n\n'));
    },
  );
}

/// Downloads each missing model in [languages], returning how long each
/// took in milliseconds.
///
/// Completion is detected by checking for the model once a second rather
/// than by awaiting the download: on iOS, `google_mlkit_translation` 0.15.1
/// never completes a download's future, and reports it as failed once any
/// other model call is made, even though the model arrives.
Future<Map<String, int>> _downloadModels(
  Set<TranslateLanguage> languages,
) async {
  final models = TranslationModels();
  final took = <String, int>{};
  for (final language in languages) {
    if (await models.isDownloaded(language)) {
      print('${language.name} is already on the device');
      continue;
    }
    print('Downloading ${language.name}...');
    final watch = Stopwatch()..start();
    unawaited(
      models
          .download(language, wifiOnly: false)
          .then<void>((_) {}, onError: (Object _) {}),
    );
    while (!await models.isDownloaded(language)) {
      if (watch.elapsed > const Duration(minutes: 5)) {
        throw TimeoutException(
          "${language.name}'s model didn't arrive",
          watch.elapsed,
        );
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    took[language.name] = watch.elapsedMilliseconds;
    print('Downloaded ${language.name} in ${watch.elapsedMilliseconds} ms');
  }
  return took;
}

/// What [result] read, for matching against expectations.
List<ReadParagraphText> _texts(ReadResult result) => [
  for (final p in result.paragraphs)
    (
      sourceText: p.sourceText,
      sourceLanguage: p.sourceLanguage,
      translatedText: p.translatedText,
    ),
];

const _stages = ['recognitionMs', 'translationMs', 'samplingMs', 'totalMs'];

Map<String, int> _timings(ReadResult result) => {
  'recognitionMs': result.timings.recognition.inMilliseconds,
  'translationMs': result.timings.translation.inMilliseconds,
  'samplingMs': result.timings.sampling.inMilliseconds,
  'totalMs': result.timings.total.inMilliseconds,
};

/// The median and max of each stage over [reads].
Map<String, Object> _stats(List<ReadResult> reads) {
  final timings = [for (final read in reads) _timings(read)];
  return {
    'median': {
      for (final stage in _stages)
        stage: _median([for (final t in timings) t[stage]!]),
    },
    'max': {
      for (final stage in _stages)
        stage: [for (final t in timings) t[stage]!].reduce(math.max),
    },
  };
}

/// The median of [values], the lower middle one for an even count.
int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[(sorted.length - 1) ~/ 2];
}

/// The median across frames of each stage, for cold, warm and stream reads.
Map<String, Map<String, int>> _summary(List<Map<String, Object?>> results) {
  Map<String, int> across(Map<String, int> Function(Map<String, Object?>) of) {
    final timings = [for (final r in results) of(r)];
    return {
      for (final stage in _stages)
        stage: timings.isEmpty
            ? 0
            : _median([for (final t in timings) t[stage]!]),
    };
  }

  Map<String, int> median(Object? stats) =>
      (stats! as Map<String, Object>)['median']! as Map<String, int>;
  return {
    'cold': across((r) => r['cold']! as Map<String, int>),
    'warm': across((r) => median(r['warm'])),
    'stream': across((r) => median(r['stream'])),
  };
}

void _printTable(
  List<Map<String, Object?>> results,
  Map<String, Map<String, int>> summary,
) {
  String row(List<Object?> cells) => [
    cells.first.toString().padRight(28),
    for (final cell in cells.skip(1)) cell.toString().padLeft(7),
  ].join(' ');
  Map<String, int> median(Object? stats) =>
      (stats! as Map<String, Object>)['median']! as Map<String, int>;
  print(
    row([
      'frame',
      'ok',
      'paras',
      'cold',
      'warm',
      'stream',
      'ocr',
      'transl',
      'colour',
      'strm ok',
    ]),
  );
  for (final r in results) {
    final cold = r['cold']! as Map<String, int>;
    final warm = median(r['warm']);
    final stream = r['stream']! as Map<String, Object>;
    final streamMedian = median(stream);
    print(
      row([
        r['file'],
        r['passed']! as bool ? 'yes' : 'NO',
        r['paragraphs'],
        cold['totalMs'],
        warm['totalMs'],
        streamMedian['totalMs'],
        streamMedian['recognitionMs'],
        streamMedian['translationMs'],
        streamMedian['samplingMs'],
        stream['passed']! as bool ? 'yes' : 'no',
      ]),
    );
  }
  final stream = summary['stream']!;
  print(
    row([
      'median of all frames',
      '',
      '',
      summary['cold']!['totalMs'],
      summary['warm']!['totalMs'],
      stream['totalMs'],
      stream['recognitionMs'],
      stream['translationMs'],
      stream['samplingMs'],
      '',
    ]),
  );
  print(
    'Times in ms. warm and stream are medians of $_warmReads reads; ocr, '
    'transl and colour are from the stream reads.',
  );
}
