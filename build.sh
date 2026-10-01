#!/usr/bin/env bash
# Build the Shop Stock release APK in one command.
# Prereq: Flutter SDK installed and on PATH (https://docs.flutter.dev/get-started/install)
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Generating Android project shell"
rm -rf .build_tmp
flutter create .build_tmp --platforms=android --org com.example --project-name shop_stock >/dev/null

echo "==> Assembling project"
rm -rf .build_tmp/test
cp -r lib .build_tmp/
cp -r test .build_tmp/
cp pubspec.yaml .build_tmp/

echo "==> Patching Android config (minSdk 21, app label)"
APP_GRADLE=.build_tmp/android/app/build.gradle
if grep -q "minSdk = flutter.minSdkVersion" "$APP_GRADLE" 2>/dev/null; then
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 21/' "$APP_GRADLE"
elif grep -q "minSdkVersion flutter.minSdkVersion" "$APP_GRADLE" 2>/dev/null; then
  sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 21/' "$APP_GRADLE"
fi
sed -i 's/android:label="shop_stock"/android:label="Shop Stock"/' \
  .build_tmp/android/app/src/main/AndroidManifest.xml

cd .build_tmp
echo "==> flutter pub get"
flutter pub get
echo "==> flutter analyze"
flutter analyze
echo "==> flutter test"
flutter test
echo "==> Building release APK"
flutter build apk --release

APK=build/app/outputs/flutter-apk/app-release.apk
cp "$APK" ../shop_stock-release.apk
echo
echo "DONE -> $(cd .. && pwd)/shop_stock-release.apk"
