@echo off
setlocal EnableExtensions
cd /d "%~dp0..\.."

if not exist "pubspec.yaml" (
  echo Ожидался каталог dk_pos рядом с этим bat. Текущая папка: %CD%
  exit /b 1
)

if not exist "installer.iss" (
  echo Не найден installer.iss в %CD%
  exit /b 1
)

REM Источник правды — version в pubspec.yaml (часть до +). installer.iss синхронизируется.
REM   build-pos-installer.bat           — sync + flutter build windows + Inno
REM   build-pos-installer.bat bump      — +1 патч и +1 build, затем сборка + Inno
REM   build-pos-installer.bat 1.0.15    — явная версия (pubspec 1.0.15+1) + .iss

if /i "%~1"=="bump" (
  echo === Версия: bump patch + build (pubspec.yaml + installer.iss) ===
  call node scripts\setInstallerVersion.js --bump-patch
  if errorlevel 1 exit /b 1
) else if not "%~1"=="" (
  echo === Версия: %~1 (pubspec.yaml + installer.iss) ===
  call node scripts\setInstallerVersion.js %~1
  if errorlevel 1 exit /b 1
) else (
  echo === Версия: sync из pubspec.yaml в installer.iss ===
  call node scripts\setInstallerVersion.js --sync
  if errorlevel 1 exit /b 1
)

where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter не найден в PATH. Добавьте Flutter SDK в PATH и повторите.
  exit /b 1
)

echo.
echo === flutter pub get ===
call flutter pub get
if errorlevel 1 exit /b 1

echo.
echo === flutter build windows --release ===
call flutter build windows --release
if errorlevel 1 exit /b 1

if not exist "build\windows\x64\runner\Release\dk_pos.exe" (
  echo Ошибка: не найден build\windows\x64\runner\Release\dk_pos.exe после сборки.
  exit /b 1
)

if not defined INNO_SETUP_DIR set "INNO_SETUP_DIR=M:\inno setup\Inno Setup 6"
set "ISCC=%INNO_SETUP_DIR%\ISCC.exe"
if not exist "%ISCC%" (
  echo Не найден компилятор Inno Setup: "%ISCC%"
  echo Задайте путь: set INNO_SETUP_DIR=C:\Path\To\Inno Setup 6
  exit /b 1
)

echo.
echo === Inno Setup: "%ISCC%" ===
"%ISCC%" "%CD%\installer.iss"
if errorlevel 1 exit /b 1

echo.
echo Готово. Установщик в build\windows_installer:
dir /b "%CD%\build\windows_installer\doner-kebab-pos-setup-*.exe" 2>nul
if errorlevel 1 echo (если список пуст — проверьте вывод ISCC выше)
exit /b 0
