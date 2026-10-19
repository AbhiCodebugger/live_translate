/// A writing system that live text recognition can read.
///
/// Each selected script runs its own on-device recognizer, so select only the
/// scripts you expect to see in the camera view.
///
/// Scripts are constants rather than an enum, so new ones can be added in a
/// minor release. A `switch` expression over a script needs a `_` case.
final class TextScript {
  const TextScript._(this.name);

  /// Latin script, for English, Spanish, French, German and similar languages.
  ///
  /// Bundled with the text recognition plugin by default.
  static const latin = TextScript._('latin');

  /// Devanagari script, for Hindi, Marathi, Nepali and similar languages.
  ///
  /// Apps must add the Devanagari recognition model on Android and iOS; see
  /// the package README for setup.
  static const devanagari = TextScript._('devanagari');

  /// Every supported script.
  static const List<TextScript> values = [latin, devanagari];

  /// The script's name, such as `latin`.
  final String name;

  @override
  String toString() => 'TextScript.$name';
}
