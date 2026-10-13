# Release checklist

Work through this for every release to pub.dev. Copy it into the release's tracking issue or PR description, and tick as you go. Version numbers follow semver: until 1.0, a minor bump (`0.x.0`) may break the API, and a patch (`0.x.y`) must not.

## 1. Prepare

- [ ] `main` is up to date, and the working tree is clean (`git status`).
- [ ] `version` in `pubspec.yaml` is the new version.
- [ ] `CHANGELOG.md` has a `## <version>` entry at the top, describing what users get rather than how it was built. Breaking changes come first, marked **Breaking**.
- [ ] `README.md` matches the release:
  - [ ] the install line;
  - [ ] the platform setup: minimum SDK and iOS version, and the Devanagari versions, which must match `google_mlkit_text_recognition`'s README;
  - [ ] the snippets;
  - [ ] the limitations.
- [ ] Dependencies are current enough: run `flutter pub outdated`, and note any major bump in the CHANGELOG.
- [ ] Any OpenSpec change shipping in this release is archived, and its specs are synced: `openspec list` shows nothing in flight.

## 2. Automated checks

- [ ] CI is green on the commit you'll publish: the Linux tests and dry run, the Android build, and the macOS golden tests and iOS build.
- [ ] Locally, `flutter pub publish --dry-run` reports no warnings. The archive must not contain `openspec/`, `.claude/`, `doc/images/`, `.github/` or `PLUGIN_PLAN.md`.

## 3. Manual check on devices

Use the example app built from this commit: `cd example && flutter run --release` on each device.

| Device | Portrait | Landscape |
|---|---|---|
| Android phone (current) | [ ] | [ ] |
| Android phone (mid-range) | [ ] | [ ] |
| iPhone | [ ] | [ ] |

On each device and orientation:

1. [ ] The app installs as **Live Translate** and asks for camera permission. Denying it shows "Allow camera access to translate."
2. [ ] English text, held still: translated labels appear within about a second, in the page's colours, and stay put while the hand moves a little.
3. [ ] A fast swing clears the labels; holding still again reads again.
4. [ ] A Hindi sign: the source chip names Hindi, and the labels are translated.
5. [ ] Pick a target language that isn't downloaded: the target chip shows a spinner, then the translation appears without moving the camera.
6. [ ] The shutter freezes and resumes. Changing the language while frozen translates the frozen picture.
7. [ ] The torch toggles. Background the app and return: the camera restarts live and the torch shows off.
8. [ ] No jank while scanning (watch the preview for stutter).

## 4. Publish

- [ ] `dart pub publish`. Check the summary it prints, then confirm.
- [ ] Tag the release and push the tag:
  ```sh
  git tag -a v<version> -m "live_translate <version>"
  git push origin v<version>
  ```
- [ ] Create a GitHub release from the tag, with the CHANGELOG entry as notes. Attach the example's release APK: `cd example && flutter build apk --release`.

## 5. After publishing

- [ ] On pub.dev: the version is listed; the README renders, including the demo GIF; the API docs built; the platform tags show Android and iOS. Check the pub points, and note every missing point and why.
- [ ] Fresh install: `flutter create` a new app, `flutter pub add live_translate`, follow only the README, paste the quick start, then build for Android and iOS.
- [ ] Answer or label any new GitHub issues raised about the release within a week.
