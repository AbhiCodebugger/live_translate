final _hyphenatedEnd = RegExp(r'\p{L}-$', unicode: true);

/// Joins a paragraph's [lines], in reading order, into one text to translate.
///
/// Lines are trimmed and joined with a single space. A line ending in a
/// hyphen right after a letter ("distri-") is a word broken across lines, so
/// it is joined to the next line without the hyphen or a space.
String joinParagraph(List<String> lines) {
  final buffer = StringBuffer();
  final trimmed = [
    for (final line in lines)
      if (line.trim() case final text when text.isNotEmpty) text,
  ];
  for (final (i, line) in trimmed.indexed) {
    final last = i == trimmed.length - 1;
    if (!last && _hyphenatedEnd.hasMatch(line)) {
      buffer.write(line.substring(0, line.length - 1));
    } else {
      buffer.write(line);
      if (!last) buffer.write(' ');
    }
  }
  return buffer.toString();
}
