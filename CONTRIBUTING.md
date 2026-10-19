# Contributing to live_translate

Thanks for helping. Bug reports, photos of text that reads wrongly, docs fixes and code are all welcome.

## Reporting a problem

Open an [issue](https://github.com/AbhiCodebugger/live_translate/issues/new/choose) and pick a template: **Bug report**, **Text read or translated wrongly**, or **Feature request**. For a problem, include:
- the phone model and OS version, and the package and Flutter versions;
- what you pointed the camera at, what you expected and what you saw;
- if you can, a screenshot with `showDebugHud: true`, which shows whether reads happen and how long they take.

A photo of the text that went wrong helps most. See [Adding a replay photo](#adding-a-replay-photo) for turning it into a test.

## Proposing a change

For anything bigger than a small fix, open an issue first, so we can agree on the approach before you write the code.

The behaviour the package promises is written down as specs in [`openspec/specs/`](openspec/specs/), one folder per capability. They take precedence over other docs. A pull request that changes behaviour updates the matching spec, including a scenario for the new behaviour.

## Setting up

You need Flutter (stable) and a real Android or iOS device: ML Kit doesn't run on simulators, the web or desktop.

```sh
git clone https://github.com/AbhiCodebugger/live_translate.git
cd live_translate
flutter pub get
cd example && flutter run
```

Platform setup for the example app is already done. For your own app, see the README's [Platform setup](README.md#platform-setup).

## Before opening a pull request

Run what CI runs:

```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test --exclude-tags golden
(cd example && flutter analyze && flutter test)
flutter pub publish --dry-run
```

- **Golden tests:** `flutter test --tags golden` compares the label painting with images recorded on macOS. Linux draws text slightly differently, so run and update them on a Mac (`flutter test --tags golden --update-goldens`). CI runs them on macOS.
- **Replay tests:** `example/integration_test/replay_test.dart` runs real photos through ML Kit on a phone. Run it when you change recognition, language detection or translation; see the [example's README](example/README.md#replay-tests).
- **Benchmarks:** `flutter test --tags benchmark --run-skipped` times the hot paths on your machine. Use it to compare before and after a performance change, on the same machine.
- **Tests and coverage:** new behaviour comes with tests. Line coverage of `lib/src/geometry`, `live`, `motion`, `still`, `cache` and `pipeline` stays at 90% or more (`flutter test --coverage --exclude-tags golden` writes `coverage/lcov.info`).
- **Docs:** a change to the public API or its behaviour updates `README.md` and adds a line under `## Unreleased` at the top of [`CHANGELOG.md`](CHANGELOG.md), describing what users get.

## Versioning

The package follows semantic versioning from 1.0.0:
- **Major:** breaking changes, such as removing or renaming public API, changing a public type, or adding a subtype to the sealed `LiveTranslateException` or `SourceStatus`.
- **Minor:** new features that don't break existing code, such as new parameters with defaults or new `TextScript` constants.
- **Patch:** fixes and docs.

A breaking change waits for the next major version, so say in your pull request if yours is one.

## Commit messages

Start with a type, then say what the change does for users:
- `feat:` new behaviour or API;
- `fix:` a bug fix;
- `docs:` docs only;
- `test:` tests only;
- `chore:` versions, CI and tooling.

For example: `fix: finish iOS model downloads once the model is on the device`.

## Adding a replay photo

Photos of real signs, menus and pages are the package's best tests.

1. Take a photo of public text only, with no faces or personal details: the repository is public.
2. Follow [Adding a frame](example/README.md#adding-a-frame) in the example's README. A script turns the photo upright, strips all EXIF data including location, and resizes it. Then you describe the text you expect in `frames.json`.
3. Run the replay test on a phone and include the result in your pull request.

## Where help is most useful

- Chinese, Japanese and Korean scripts.
- Rotated and vertical text.
- iOS paragraph grouping: ML Kit on iOS splits some paragraphs into one-word fragments, which translate badly. The replay photos already show it.
- More replay photos, especially of Devanagari text and of languages the tests don't cover yet.

## License

By contributing, you agree that your contribution is licensed under the package's [BSD 3-Clause license](LICENSE).
