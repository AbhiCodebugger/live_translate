/// A writing system that live text recognition can read.
///
/// Each selected script runs its own on-device recognizer, so select only the
/// scripts you expect to see in the camera view.
enum TextScript {
  /// Latin script, for English, Spanish, French, German and similar languages.
  ///
  /// Bundled with the text recognition plugin by default.
  latin,

  /// Devanagari script, for Hindi, Marathi, Nepali and similar languages.
  ///
  /// Apps must add the Devanagari recognition model on Android and iOS; see
  /// the package README for setup.
  devanagari,
}
