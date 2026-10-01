# Shop Stock - Ready-to-Build Package

This package contains everything needed to produce the Android APK:
the app source (lib/), tests (test/), pubspec.yaml, and one-command build scripts.

## What was done since the original zip
- Added pubspec.yaml (name: shop_stock, wide dependency ranges so it resolves
  on any recent Flutter SDK).
- Fixed the future-date off-by-one in lib/data/repository.dart
  (tomorrow is no longer accepted as a valid business date).
- Added build.sh (Linux/macOS) and build.bat (Windows) that:
  1. generate the Android project shell via `flutter create`
  2. overlay this code
  3. set minSdk 21 and the "Shop Stock" app label
  4. run pub get, analyze, tests
  5. build the release APK and copy it here as shop_stock-release.apk

## How to build the APK

1. Install the Flutter SDK: https://docs.flutter.dev/get-started/install
   (one download, unzip, add `flutter/bin` to PATH; `flutter doctor` to verify)
2. From this folder run:
   - Linux/macOS:  ./build.sh
   - Windows:      build.bat
3. The APK appears here as `shop_stock-release.apk`.
   Copy it to the phone, tap to install (allow "install from unknown sources"),
   or use:  flutter install  /  adb install shop_stock-release.apk

If `flutter analyze` or `flutter test` reports anything, paste the output
and it will be fixed.

## Optional: Play-store-ready signed build
flutter build appbundle --release   (needs your own signing key configured)

## Zero-install option: build in the cloud with GitHub
1. Create a GitHub repo and upload this folder's contents (keep .github/workflows).
2. GitHub Actions builds the APK automatically on every push (free for public repos).
3. Download the APK from the Actions run page, under "Artifacts" (shop_stock-release-apk).
