import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show InputImage;

import '../models/text_script.dart';
import 'line_filter.dart';
import 'text_engine.dart';

/// Recognizes several scripts by reading each frame with every script's
/// engine, in parallel, and merging their lines.
///
/// Each script keeps only lines with enough letters of its own script, and
/// where a Latin line and a non-Latin reading overlap, the reading in the
/// text's own script wins.
final class MultiScriptTextEngine implements TextEngine {
  /// Creates an engine that reads with every one of [engines], one per
  /// script.
  MultiScriptTextEngine(Map<TextScript, TextEngine> engines)
    : assert(engines.isNotEmpty, 'At least one script is required.'),
      _engines = Map.of(engines),
      _order = [
        for (final script in TextScript.values)
          if (engines.containsKey(script)) script,
      ];

  /// Paragraph identifiers of each script are offset by this much times the
  /// script's index, so paragraphs of different scripts never share one.
  static const paragraphsPerScript = 10000;

  final Map<TextScript, TextEngine> _engines;
  final List<TextScript> _order;
  bool _closed = false;

  @override
  Future<List<RecognizedLine>> recognize(InputImage image) async {
    if (_closed) throw StateError('MultiScriptTextEngine used after close.');
    final results = await Future.wait([
      for (final script in _order) _engines[script]!.recognize(image),
    ]);
    return _merge({
      for (final (i, script) in _order.indexed)
        script: _own(script, results[i]),
    });
  }

  /// [lines] of [script] with enough letters of that script, with paragraph
  /// identifiers made unique across scripts.
  static List<RecognizedLine> _own(
    TextScript script,
    List<RecognizedLine> lines,
  ) => [
    for (final line in lines)
      if (hasEnoughLettersOf(line.text, script))
        RecognizedLine(
          text: line.text,
          box: line.box,
          paragraph:
              TextScript.values.indexOf(script) * paragraphsPerScript +
              line.paragraph,
        ),
  ];

  /// Merges every script's lines. Where a Latin line and a non-Latin line
  /// overlap, the reading in the text's actual script wins: a non-Latin
  /// line made mostly of its own letters replaces the Latin recognizer's
  /// gibberish under it, while a non-Latin recognizer's mostly-Latin
  /// misreading gives way to the Latin line.
  static List<RecognizedLine> _merge(
    Map<TextScript, List<RecognizedLine>> byScript,
  ) {
    final latin = byScript[TextScript.latin] ?? const <RecognizedLine>[];
    final nonLatin = [
      for (final MapEntry(key: script, value: lines) in byScript.entries)
        if (script != TextScript.latin)
          for (final line in lines) (script: script, line: line),
    ];
    bool ownScript(({TextScript script, RecognizedLine line}) reading) =>
        lettersOf(reading.line.text, reading.script) >=
        lettersOf(reading.line.text, TextScript.latin);

    final keptLatin = [
      for (final line in latin)
        if (!nonLatin.any(
          (other) => ownScript(other) && _covers(other.line.box, line.box),
        ))
          line,
    ];
    final keptNonLatin = [
      for (final reading in nonLatin)
        if (ownScript(reading) ||
            !latin.any((line) => _covers(line.box, reading.line.box)))
          reading,
    ];
    return [
      for (final script in TextScript.values)
        if (script == TextScript.latin)
          ...keptLatin
        else
          for (final reading in keptNonLatin)
            if (reading.script == script) reading.line,
    ];
  }

  static bool _covers(Rect cover, Rect box) {
    final area = box.width * box.height;
    if (area <= 0 || !cover.overlaps(box)) return false;
    final overlap = cover.intersect(box);
    return overlap.width * overlap.height >= area / 2;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(_engines.values.map((engine) => engine.close()));
  }
}
