import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:live_translate/src/engines/mlkit/mlkit_model_store.dart';
import 'package:live_translate/src/errors.dart';

final class _FakeManager implements ModelManager {
  final calls = <String>[];
  bool downloadResult = true;
  Object? downloadError;

  @override
  String get method => 'fake';

  @override
  MethodChannel get channel => const MethodChannel('fake');

  @override
  Future<bool> isModelDownloaded(String model) async {
    calls.add('check $model');
    return model == 'hi';
  }

  @override
  Future<bool> downloadModel(String model, {bool isWifiRequired = true}) async {
    calls.add('download $model wifi=$isWifiRequired');
    if (downloadError case final error?) throw error;
    return downloadResult;
  }

  @override
  Future<bool> deleteModel(String model) async {
    calls.add('delete $model');
    return true;
  }
}

/// A model manager behaving like the iOS plugin: its download call answers
/// only when [downloadAnswer] says so, and the model arrives on its own.
final class _IosManager implements ModelManager {
  final calls = <String>[];
  final present = <String>{};

  /// What the download call does; never completes by default.
  Future<bool> Function() downloadAnswer = () => Completer<bool>().future;

  @override
  String get method => 'fake';

  @override
  MethodChannel get channel => const MethodChannel('fake');

  @override
  Future<bool> isModelDownloaded(String model) async {
    calls.add('check $model');
    return present.contains(model);
  }

  @override
  Future<bool> downloadModel(String model, {bool isWifiRequired = true}) {
    calls.add('download $model');
    return downloadAnswer();
  }

  @override
  Future<bool> deleteModel(String model) async => true;
}

void main() {
  late _FakeManager manager;
  late MlKitModelStore store;

  setUp(() {
    manager = _FakeManager();
    store = MlKitModelStore(manager: manager);
  });

  test('checks a model by its BCP-47 code', () async {
    expect(await store.isDownloaded(TranslateLanguage.hindi), isTrue);
    expect(await store.isDownloaded(TranslateLanguage.marathi), isFalse);
    expect(manager.calls, ['check hi', 'check mr']);
  });

  test('passes the Wi-Fi requirement through', () async {
    await store.download(TranslateLanguage.hindi, wifiOnly: true);
    await store.download(TranslateLanguage.spanish, wifiOnly: false);
    expect(manager.calls, ['download hi wifi=true', 'download es wifi=false']);
  });

  test('a false result means the download failed', () async {
    manager.downloadResult = false;
    await expectLater(
      store.download(TranslateLanguage.hindi, wifiOnly: true),
      throwsA(
        isA<ModelNotDownloaded>().having(
          (e) => e.language,
          'language',
          TranslateLanguage.hindi,
        ),
      ),
    );
  });

  test('a platform error means the download failed', () async {
    manager.downloadError = PlatformException(code: 'download-failed');
    await expectLater(
      store.download(TranslateLanguage.hindi, wifiOnly: true),
      throwsA(isA<ModelNotDownloaded>()),
    );
  });

  test('deletes a model by its BCP-47 code', () async {
    await store.delete(TranslateLanguage.hindi);
    expect(manager.calls, ['delete hi']);
  });
  test('Android awaits the download call without checking', () async {
    final android = MlKitModelStore(
      manager: manager,
      platform: TargetPlatform.android,
    );
    await android.download(TranslateLanguage.spanish, wifiOnly: false);
    expect(manager.calls, ['download es wifi=false']);
  });

  group('on iOS', () {
    late _IosManager ios;
    late int waits;

    /// A store whose wait is instant and runs [onWait] after each one.
    MlKitModelStore iosStore({void Function(int waits)? onWait}) =>
        MlKitModelStore(
          manager: ios,
          platform: TargetPlatform.iOS,
          wait: (duration) async {
            expect(duration, MlKitModelStore.checkInterval);
            waits++;
            onWait?.call(waits);
          },
        );

    setUp(() {
      ios = _IosManager();
      waits = 0;
    });

    test('completes once the model arrives, though the call never '
        'answers', () async {
      final store = iosStore(
        onWait: (n) {
          if (n == 3) ios.present.add('hi');
        },
      );
      await store.download(TranslateLanguage.hindi, wifiOnly: true);
      expect(waits, 3);
      expect(ios.calls, [
        'check hi',
        'download hi',
        'check hi',
        'check hi',
        'check hi',
      ]);
    });

    test('ignores a cancellation and keeps checking', () async {
      ios.downloadAnswer = () async =>
          throw PlatformException(code: 'cancelled');
      final store = iosStore(
        onWait: (n) {
          if (n == 3) ios.present.add('hi');
        },
      );
      await store.download(TranslateLanguage.hindi, wifiOnly: true);
      expect(waits, 3);
    });

    test('ignores a download already in progress', () async {
      ios.downloadAnswer = () async =>
          throw PlatformException(code: 'download_in_progress');
      final store = iosStore(
        onWait: (n) {
          if (n == 2) ios.present.add('hi');
        },
      );
      await store.download(TranslateLanguage.hindi, wifiOnly: true);
      expect(waits, 2);
    });

    test('fails after 300 checks without the model', () async {
      final store = iosStore();
      await expectLater(
        store.download(TranslateLanguage.hindi, wifiOnly: true),
        throwsA(
          isA<ModelNotDownloaded>().having(
            (e) => e.language,
            'language',
            TranslateLanguage.hindi,
          ),
        ),
      );
      expect(waits, MlKitModelStore.maxChecks);
      expect(
        ios.calls.where((c) => c == 'check hi'),
        hasLength(MlKitModelStore.maxChecks + 1),
      );
    });

    test('completes at once when the model is already there', () async {
      ios.present.add('hi');
      await iosStore().download(TranslateLanguage.hindi, wifiOnly: true);
      expect(waits, 0);
      expect(ios.calls, ['check hi']);
    });

    test("honours the call's success", () async {
      ios.downloadAnswer = () async => true;
      await iosStore().download(TranslateLanguage.hindi, wifiOnly: true);
      expect(ios.present, isEmpty);
    });

    test("fails at once on the call's failure", () async {
      ios.downloadAnswer = () async => false;
      await expectLater(
        iosStore().download(TranslateLanguage.hindi, wifiOnly: true),
        throwsA(isA<ModelNotDownloaded>()),
      );
      expect(waits, lessThanOrEqualTo(1));
    });

    test('fails at once on another platform error', () async {
      ios.downloadAnswer = () async =>
          throw PlatformException(code: 'download-failed');
      await expectLater(
        iosStore().download(TranslateLanguage.hindi, wifiOnly: true),
        throwsA(isA<ModelNotDownloaded>()),
      );
      expect(waits, lessThanOrEqualTo(1));
    });

    test('stops checking once finished', () async {
      final store = iosStore(
        onWait: (n) {
          if (n == 2) ios.present.add('hi');
        },
      );
      await store.download(TranslateLanguage.hindi, wifiOnly: true);
      final checks = ios.calls.length;
      await pumpEventQueue();
      expect(ios.calls, hasLength(checks));
      expect(waits, 2);
    });

    test('stops checking once the call answers', () async {
      final answer = Completer<bool>();
      ios.downloadAnswer = () => answer.future;
      final store = iosStore(
        onWait: (n) {
          if (n == 2) answer.complete(true);
        },
      );
      await store.download(TranslateLanguage.hindi, wifiOnly: true);
      await pumpEventQueue();
      expect(waits, 2);
    });
  });
}
