import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:meta/meta.dart';

import '../../errors.dart';
import '../model_store.dart';

/// A [ModelStore] backed by ML Kit's translation model manager.
///
/// On iOS, `google_mlkit_translation` never completes a download's call: it
/// waits for a notification ML Kit doesn't send, and answers `cancelled` as
/// soon as any other model call is made. There, a download is finished once
/// the model is on the device, checked once a second.
final class MlKitModelStore implements ModelStore {
  /// Creates a store.
  ///
  /// [manager] exists so tests can substitute a fake.
  MlKitModelStore({
    ModelManager? manager,
    @internal this._platform,
    @internal Future<void> Function(Duration duration)? wait,
  }) : _manager = manager ?? OnDeviceTranslatorModelManager(),
       _wait = wait ?? Future<void>.delayed;

  /// How often an iOS download checks whether its model has arrived.
  static const checkInterval = Duration(seconds: 1);

  /// How many checks an iOS download makes before it fails: at least 5
  /// minutes.
  static const maxChecks = 300;

  final ModelManager _manager;
  final TargetPlatform? _platform;
  final Future<void> Function(Duration duration) _wait;

  @override
  Future<bool> isDownloaded(TranslateLanguage language) =>
      _manager.isModelDownloaded(language.bcpCode);

  @override
  Future<void> download(
    TranslateLanguage language, {
    required bool wifiOnly,
  }) async {
    if ((_platform ?? defaultTargetPlatform) == TargetPlatform.iOS) {
      return _downloadOnIos(language, wifiOnly: wifiOnly);
    }
    final bool succeeded;
    try {
      succeeded = await _manager.downloadModel(
        language.bcpCode,
        isWifiRequired: wifiOnly,
      );
    } on PlatformException {
      throw ModelNotDownloaded(language);
    }
    if (!succeeded) throw ModelNotDownloaded(language);
  }

  /// Starts the download and finishes on whichever comes first: the
  /// platform's own answer, or the model found on the device.
  Future<void> _downloadOnIos(
    TranslateLanguage language, {
    required bool wifiOnly,
  }) async {
    if (await isDownloaded(language)) return;

    var finished = false;
    final done = Completer<void>();
    void finish([Object? error]) {
      if (finished) return;
      finished = true;
      error == null ? done.complete() : done.completeError(error);
    }

    // The iOS plugin ignores the Wi-Fi requirement and always allows mobile
    // data.
    unawaited(
      _manager
          .downloadModel(language.bcpCode, isWifiRequired: wifiOnly)
          .then<void>(
            (succeeded) =>
                finish(succeeded ? null : ModelNotDownloaded(language)),
            onError: (Object error) {
              // A replaced manager cancels; another download of this model
              // may already be running. Either way, keep checking.
              if (error case PlatformException(
                code: 'cancelled' || 'download_in_progress',
              )) {
                return;
              }
              finish(ModelNotDownloaded(language));
            },
          ),
    );

    unawaited(() async {
      for (var check = 0; check < maxChecks && !finished; check++) {
        await _wait(checkInterval);
        if (finished) return;
        final bool arrived;
        try {
          arrived = await isDownloaded(language);
        } on Object {
          continue;
        }
        if (arrived) return finish();
      }
      finish(ModelNotDownloaded(language));
    }());

    return done.future;
  }

  @override
  Future<void> delete(TranslateLanguage language) =>
      _manager.deleteModel(language.bcpCode);
}
