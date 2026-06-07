@echo off
setlocal EnableExtensions
cd /d "%~dp0"

if not exist "pubspec.yaml" (
  echo Ожидался каталог dk_pos. Текущая папка: %CD%
  exit /b 1
)

REM   build-pos-apk.bat           — sync + APK (кухня / pos_android)
REM   build-pos-apk.bat bump      — +1 патч в pubspec, затем APK
REM   build-pos-apk.bat 1.0.15    — явная версия, затем APK

if /i "%~1"=="bump" (
  echo === POS Android: bump patch ===
  call node scripts\setInstallerVersion.js --bump-patch
  if errorlevel 1 exit /b 1
) else if not "%~1"=="" (
  echo === POS Android: версия %~1 ===
  call node scripts\setInstallerVersion.js %~1
  if errorlevel 1 exit /b 1
) else (
  call node scripts\setInstallerVersion.js --sync
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter не найден в PATH.
  exit /b 1
)

echo.
echo === flutter pub get ===
call flutter pub get
if errorlevel 1 exit /b 1

echo.
echo === flutter build apk --release (arm64) ===
call flutter build apk --release --target-platform android-arm64
if errorlevel 1 exit /b 1

echo.
echo Готово. APK для global (компонент pos_android):
echo   %CD%\build\app\outputs\flutter-apk\app-release.apk
for /f "delims=" %%V in ('node -e "const fs=require('fs');const m=fs.readFileSync('pubspec.yaml','utf8').match(/^version:\\s*(\\S+)/m);console.log(m?m[1].split('+')[0]:'?');"') do echo   Версия в админке: %%V
exit /b 0
