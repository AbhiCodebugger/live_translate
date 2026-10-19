import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:meta/meta.dart' show internal;

import 'engines/mlkit/mlkit_model_store.dart';
import 'engines/model_store.dart';

/// Manages the on-device translation models, for apps that want to offer
/// downloads from their own UI.
///
/// Each language's model is about 30 MB. The live view downloads the models
/// it needs automatically, on any network, so most apps never need this
/// class.
///
/// ```dart
/// final models = TranslationModels();
/// if (!await models.isDownloaded(TranslateLanguage.hindi)) {
///   await models.download(TranslateLanguage.hindi);
/// }
/// ```
///
/// The platform reports when a download finishes, not how far it has got, so
/// show an indeterminate progress indicator while [download] runs.
final class TranslationModels {
  /// Creates a model manager backed by ML Kit.
  TranslationModels() : _store = MlKitModelStore();

  /// Creates a model manager backed by [store].
  ///
  /// For this package's tests only.
  @internal
  TranslationModels.withStore(ModelStore store) : _store = store;

  final ModelStore _store;

  /// Whether [language]'s model is on the device.
  Future<bool> isDownloaded(TranslateLanguage language) =>
      _store.isDownloaded(language);

  /// Downloads [language]'s model and completes once it is on the device.
  ///
  /// With [wifiOnly] (the default), the download waits for a Wi-Fi
  /// connection instead of using mobile data, so on mobile data this may not
  /// complete until the device joins Wi-Fi.
  ///
  /// On iOS, ML Kit always downloads on any network, so [wifiOnly] has no
  /// effect, and it doesn't report a failed download: there, the download
  /// fails if the model isn't on the device within 5 minutes.
  ///
  /// Throws `ModelNotDownloaded` if the download fails.
  Future<void> download(TranslateLanguage language, {bool wifiOnly = true}) =>
      _store.download(language, wifiOnly: wifiOnly);

  /// Removes [language]'s model from the device.
  Future<void> delete(TranslateLanguage language) => _store.delete(language);

  /// The languages whose models are on the device.
  Future<Set<TranslateLanguage>> downloaded() async {
    final languages = TranslateLanguage.values;
    final present = await Future.wait(languages.map(_store.isDownloaded));
    return {
      for (var i = 0; i < languages.length; i++)
        if (present[i]) languages[i],
    };
  }
}
