#!/usr/bin/env bash
# Measures how much live_translate adds to an app's size.
#
#   tool/size_impact.sh
#
# Builds three release apps in a temporary directory, never touching the
# checkout:
#
#   bare        a new `flutter create` app (minSdk 24, iOS 15.5)
#   latin       the example app without the Devanagari recognizer
#   devanagari  the example app as shipped, with Latin and Devanagari
#
# The example copies leave out the replay test photos, which only the
# integration tests use. For each app it reports the arm64 release APK and
# the iOS Runner.app, zipped (close to an IPA) and unzipped, then prints a
# Markdown table. Sizes are in MB (1,000,000 bytes).
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/live_translate_size.XXXXXX")"
trap 'rm -rf "$work"' EXIT
log="$work/build.log"
results="$work/results.tsv"

say() { printf '%s\n' "$*" >&2; }

# Builds the app in $2 and appends "name<TAB>apk<TAB>ipa<TAB>app" in bytes.
build() {
  local name="$1" dir="$2"
  say "Building $name..."
  local apk app zip
  apk="$dir/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
  app="$dir/build/ios/iphoneos/Runner.app"
  # Chained with && because set -e doesn't apply inside a subshell tested
  # by ||.
  if ! (
    cd "$dir" &&
      flutter pub get >>"$log" 2>&1 &&
      flutter build apk --release --split-per-abi \
        --target-platform android-arm64 >>"$log" 2>&1 &&
      flutter build ios --release --no-codesign >>"$log" 2>&1
  ) || [[ ! -f "$apk" || ! -d "$app" ]]; then
    say "Building $name failed; the end of the log:"
    tail -40 "$log" >&2
    exit 1
  fi
  zip="$work/$name.zip"
  ditto -c -k --keepParent "$app" "$zip"
  printf '%s\t%s\t%s\t%s\n' "$name" \
    "$(stat -f %z "$apk")" \
    "$(stat -f %z "$zip")" \
    "$(find "$app" -type f -exec stat -f %z {} + | awk '{s += $1} END {print s}')" \
    >>"$results"
}

# A copy of the example app that depends on this checkout and leaves out
# the replay photos.
copy_example() {
  local dir="$1"
  rsync -a --exclude build --exclude .dart_tool --exclude ios/Pods \
    --exclude assets/replay_frames "$repo/example/" "$dir/"
  sed -i '' -e "s#path: \.\./#path: $repo/#" \
    -e '/^  assets:/d' -e '/^    - assets\/replay_frames\//d' "$dir/pubspec.yaml"
}

say "Working in $work (log: $log)"
: >"$results"

flutter create --platforms android,ios --org dev.size --project-name bare \
  "$work/bare" >>"$log" 2>&1
sed -i '' -e 's/minSdk = flutter.minSdkVersion/minSdk = 24/' \
  "$work/bare/android/app/build.gradle.kts"
if [[ -f "$work/bare/ios/Podfile" ]]; then
  sed -i '' -e "s/^# platform :ios.*/platform :ios, '15.5'/" \
    "$work/bare/ios/Podfile"
fi
build bare "$work/bare"

copy_example "$work/latin"
sed -i '' -e '/text-recognition-devanagari/d' \
  "$work/latin/android/app/build.gradle.kts"
sed -i '' -e '/TextRecognitionDevanagari/d' "$work/latin/ios/Podfile"
# Without the recognizer, R8 also needs to ignore the plugin's reference to
# it, as the README's Latin-only setup says.
echo '-dontwarn com.google.mlkit.vision.text.devanagari.**' \
  >>"$work/latin/android/app/proguard-rules.pro"
rm -f "$work/latin/ios/Podfile.lock"
build latin "$work/latin"

copy_example "$work/devanagari"
build devanagari "$work/devanagari"

awk -F'\t' '
  function mb(bytes) { return sprintf("%.1f", bytes / 1000000) }
  function diff(a, b) { return sprintf("+%.1f", (a - b) / 1000000) }
  { apk[$1] = $2; ipa[$1] = $3; app[$1] = $4 }
  END {
    print "| App | Android APK (arm64) | iOS app, zipped | iOS app, unzipped |"
    print "|---|---:|---:|---:|"
    print "| Bare Flutter app | " mb(apk["bare"]) " | " mb(ipa["bare"]) " | " mb(app["bare"]) " |"
    print "| Example, Latin only | " mb(apk["latin"]) " | " mb(ipa["latin"]) " | " mb(app["latin"]) " |"
    print "| Example, Latin and Devanagari | " mb(apk["devanagari"]) " | " mb(ipa["devanagari"]) " | " mb(app["devanagari"]) " |"
    print "| live_translate, Latin only (over bare) | " diff(apk["latin"], apk["bare"]) " | " diff(ipa["latin"], ipa["bare"]) " | " diff(app["latin"], app["bare"]) " |"
    print "| Devanagari recognizer (over Latin only) | " diff(apk["devanagari"], apk["latin"]) " | " diff(ipa["devanagari"], ipa["latin"]) " | " diff(app["devanagari"], app["latin"]) " |"
  }' "$results"
