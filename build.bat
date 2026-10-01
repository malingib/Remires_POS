@echo off
REM Build the Shop Stock release APK in one command (Windows).
REM Prereq: Flutter SDK installed and on PATH.
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ==^> Generating Android project shell
if exist .build_tmp rmdir /s /q .build_tmp
flutter create .build_tmp --platforms=android --org com.example --project-name shop_stock >nul

echo ==^> Assembling project
rmdir /s /q .build_tmp\test 2>nul
xcopy /e /i /q /y lib .build_tmp\lib >nul
xcopy /e /i /q /y test .build_tmp\test >nul
copy /y pubspec.yaml .build_tmp\pubspec.yaml >nul

echo ==^> Patching Android config
set "G=.build_tmp\android\app\build.gradle"
powershell -NoProfile -Command "(Get-Content '%G%') -replace 'minSdk ?= ?flutter\.minSdkVersion','minSdk = 21' | Set-Content '%G%'"
powershell -NoProfile -Command "(Get-Content '.build_tmp\android\app\src\main\AndroidManifest.xml') -replace 'android:label="shop_stock"','android:label="Shop Stock"' | Set-Content '.build_tmp\android\app\src\main\AndroidManifest.xml'"

cd .build_tmp
echo ==^> flutter pub get
call flutter pub get || goto :fail
echo ==^> flutter analyze
call flutter analyze || goto :fail
echo ==^> flutter test
call flutter test || goto :fail
echo ==^> Building release APK
call flutter build apk --release || goto :fail

copy /y build\app\outputs\flutter-apk\app-release.apk ..\shop_stock-release.apk >nul
cd ..
echo DONE -^> %CD%\shop_stock-release.apk
exit /b 0

:fail
echo BUILD FAILED - see messages above
exit /b 1
