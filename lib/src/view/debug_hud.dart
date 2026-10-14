import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../pipeline/pipeline_metrics.dart';

/// What the debug HUD shows: the latest shown read, if any, and how many
/// live frames the view measured in the last second.
typedef DebugHudData = ({PipelineMetrics? latest, int framesPerSecond});

/// A small panel of the latest read's timings and the frame rate, drawn in
/// the top-left corner, clear of the system's status bar and notches. It
/// ignores touches.
class DebugHud extends StatelessWidget {
  /// Creates a HUD showing [data].
  const DebugHud({super.key, required this.data});

  /// What to show; the HUD rebuilds whenever it changes.
  final ValueListenable<DebugHudData> data;

  /// The HUD's lines for [data].
  static List<String> linesFor(DebugHudData data) {
    final fps = '${data.framesPerSecond} fps';
    final latest = data.latest;
    if (latest == null) return ['no read yet', fps];
    final count = latest.paragraphs;
    return [
      'read ${latest.total.inMilliseconds} ms'
          '${latest.frozen ? ' (frozen)' : ''}',
      'ocr ${latest.recognition.inMilliseconds} · '
          'translate ${latest.translation.inMilliseconds} · '
          'colours ${latest.sampling.inMilliseconds}',
      '$count ${count == 1 ? 'paragraph' : 'paragraphs'} · $fps',
    ];
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0x99000000),
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: ValueListenableBuilder(
                valueListenable: data,
                builder: (context, value, _) => Text(
                  linesFor(value).join('\n'),
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
