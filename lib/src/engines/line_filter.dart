import '../models/text_script.dart';

// Letters of each script. Devanagari vowel signs belong to the script but are
// marks rather than letters, so the lookahead leaves them out.
final _scriptLetters = {
  TextScript.latin: RegExp(r'(?=\p{L})\p{Script=Latin}', unicode: true),
  TextScript.devanagari: RegExp(
    r'(?=\p{L})\p{Script=Devanagari}',
    unicode: true,
  ),
};

/// Whether [text] contains at least one letter of [script].
bool hasLetterOf(String text, TextScript script) =>
    _scriptLetters[script]!.hasMatch(text);

/// Whether [text] contains at least two letters of [script], the script of
/// the recognizer that read it.
///
/// Lines that fail are dropped: very short lines, digits-only lines and
/// punctuation-only lines are noise on signage, and the Devanagari
/// recognizer also reads Latin text, badly. Vowel signs are marks rather than
/// letters, so a one-syllable word such as "है" counts as one letter.
bool hasEnoughLettersOf(String text, TextScript script) =>
    _scriptLetters[script]!.allMatches(text).take(2).length == 2;

/// How many letters of [script] [text] contains.
int lettersOf(String text, TextScript script) =>
    _scriptLetters[script]!.allMatches(text).length;
