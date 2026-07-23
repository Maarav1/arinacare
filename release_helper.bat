@echo off
echo ================================================
echo    ArinaCave Release Helper
echo    Version Update + Symbols + Firebase
echo ================================================
echo.

cd /d "%~dp0"

:: ===================== CONFIG =====================
set FIREBASE_APP_ID=lifematters-c466d
:: =================================================

echo [1] Updating version number...
for /f "tokens=2 delims=+" %%a in ('findstr "version:" pubspec.yaml') do set OLD_BUILD=%%a
set /a NEW_BUILD=%OLD_BUILD%+1
powershell -command "(gc pubspec.yaml) -replace 'version: .+\+.*', 'version: 1.0.0+%NEW_BUILD%' | Set-Content pubspec.yaml"
echo Version updated to 1.0.0+%NEW_BUILD%

echo [2] Creating ZIP of debug symbols...
powershell -command "Compress-Archive -Path 'build\symbols' -DestinationPath 'build\symbols.zip' -Force"

echo [3] Uploading symbols to Firebase Crashlytics...
firebase crashlytics:symbols:upload --app=%FIREBASE_APP_ID% build/symbols

echo.
echo ================================================
echo READY FOR GOOGLE PLAY!
echo.
echo ✅ New Version     : 1.0.0+%NEW_BUILD%
echo ✅ App Bundle      : android\app\build\outputs\bundle\release\app-release.aab
echo ✅ Symbols ZIP     : build\symbols.zip
echo ✅ Firebase Upload : Done
echo.
echo Opening bundle folder...
explorer android\app\build\outputs\bundle\release

echo.
echo Now upload app-release.aab to Google Play Console.
pause