import 'manifest.dart';

/// One paragraph as a read produced it.
typedef ReadParagraphText = ({
  String sourceText,
  String? sourceLanguage,
  String translatedText,
});

final _dropped = RegExp('[.,:;!?\'"()«»“”‘’\\-–—]');
final _spaces = RegExp(r'\s+');

/// [text] lowercased, without punctuation, with runs of whitespace as one
/// space.
String normalize(String text) =>
    text.toLowerCase().replaceAll(_dropped, '').replaceAll(_spaces, ' ').trim();

/// Whether [paragraph] satisfies [expectation]: its text contains the
/// fragment, its language matches, and it has a real translation containing
/// one of the keywords, if any.
bool satisfies(Expectation expectation, ReadParagraphText paragraph) {
  final source = normalize(paragraph.sourceText);
  final translation = normalize(paragraph.translatedText);
  return source.contains(normalize(expectation.source)) &&
      paragraph.sourceLanguage == expectation.language &&
      translation.isNotEmpty &&
      translation != source &&
      (expectation.translation.isEmpty ||
          expectation.translation.any(
            (word) => translation.contains(normalize(word)),
          ));
}

/// The expectations of [frame] that no paragraph of [read] satisfies,
/// described with everything that was read; `null` when all are met.
String? failures(ReplayFrameSpec frame, List<ReadParagraphText> read) {
  final missing = [
    for (final expectation in frame.expect)
      if (!read.any((paragraph) => satisfies(expectation, paragraph)))
        expectation,
  ];
  if (missing.isEmpty) return null;
  return [
    '${frame.file}${frame.note.isEmpty ? '' : ' (${frame.note})'}: '
        'not found:',
    for (final expectation in missing) '  - $expectation',
    'read ${read.length} paragraph${read.length == 1 ? '' : 's'}:',
    for (final paragraph in read)
      '  - "${paragraph.sourceText}" [${paragraph.sourceLanguage}] → '
          '"${paragraph.translatedText}"',
  ].join('\n');
}
