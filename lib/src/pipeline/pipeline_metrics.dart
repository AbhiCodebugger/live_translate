import 'package:flutter/foundation.dart' show immutable;

/// How long one read of the camera picture took, stage by stage, and what it
/// produced.
///
/// A [LiveTranslateController] reports one for each read the view shows:
///
/// ```dart
/// controller.metrics.listen((metrics) {
///   debugPrint('read in ${metrics.total.inMilliseconds} ms');
/// });
/// ```
@immutable
final class PipelineMetrics {
  /// Creates the metrics of one read.
  const PipelineMetrics({
    required this.recognition,
    required this.translation,
    required this.sampling,
    required this.total,
    required this.paragraphs,
    required this.frozen,
  });

  /// Time spent preparing the frame and recognising its text, with every
  /// selected script.
  final Duration recognition;

  /// Time spent translating: detecting each paragraph's language, checking
  /// (and starting downloads of) translation models, and translating.
  ///
  /// The first read after a language change includes the model checks, so it
  /// is often slower than the reads after it.
  final Duration translation;

  /// Time spent sampling each paragraph's page and text colours.
  final Duration sampling;

  /// The whole read, from receiving the frame to the result. At least the
  /// sum of [recognition], [translation] and [sampling].
  final Duration total;

  /// How many paragraphs the read translated.
  ///
  /// This counts every translated paragraph, including any whose translation
  /// equals its source text, which the view doesn't draw.
  final int paragraphs;

  /// Whether this was the read of a frozen picture rather than a live one.
  final bool frozen;

  @override
  bool operator ==(Object other) =>
      other is PipelineMetrics &&
      other.recognition == recognition &&
      other.translation == translation &&
      other.sampling == sampling &&
      other.total == total &&
      other.paragraphs == paragraphs &&
      other.frozen == frozen;

  @override
  int get hashCode => Object.hash(
    recognition,
    translation,
    sampling,
    total,
    paragraphs,
    frozen,
  );

  @override
  String toString() =>
      'PipelineMetrics(total: ${total.inMilliseconds} ms, '
      'recognition: ${recognition.inMilliseconds} ms, '
      'translation: ${translation.inMilliseconds} ms, '
      'sampling: ${sampling.inMilliseconds} ms, '
      'paragraphs: $paragraphs, frozen: $frozen)';
}
