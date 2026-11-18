@echo off
setlocal EnableDelayedExpansion
title SuperNote - Universal Build Tool

:: =========================
:: Ρυθμίσεις
:: =========================
set "INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
set "ISS_PATH=%~dp0note_eco_new.iss"

:: Όνομα APK από το pubspec.yaml (μοναδική πηγή αλήθειας, κανόνας 13)
:: "version: 1.4.4+12" -> VER_FULL=" 1.4.4+12" -> APP_VERSION="1.4.4"
set "VER_FULL="
set "APP_VERSION=1.0"
for /f "tokens=2 delims=:" %%v in ('findstr /b /c:"version:" "%~dp0pubspec.yaml"') do set "VER_FULL=%%v"
if not defined VER_FULL goto version_ready
for /f "tokens=1 delims=+" %%v in ("%VER_FULL%") do set "APP_VERSION=%%v"
set "APP_VERSION=%APP_VERSION: =%"
:version_ready
set "NEW_APK_NAME=SuperNote_v%APP_VERSION%.apk"

set "APK_FLAG=%temp%\apk_done.flag"
set "WIN_FLAG=%temp%\win_done.flag"

:: CR για spinner
for /f %%a in ('copy /Z "%~f0" nul') do set "CR=%%a"

:: =========================
echo ========================================================
echo   STEP 1: Cleaning and Getting Dependencies...
echo ========================================================

echo [INFO] Releasing file locks...

taskkill /F /IM java.exe >nul 2>&1
taskkill /F /IM dart.exe >nul 2>&1
taskkill /F /IM adb.exe >nul 2>&1

timeout /t 1 >nul

:: Manual delete build
if exist build (
    rmdir /s /q build >nul 2>&1
)

:: Manual delete Windows ephemeral (fix Firebase SDK corruption)
if exist windows\flutter\ephemeral (
    rmdir /s /q windows\flutter\ephemeral >nul 2>&1
)

:: Retry flutter clean
set tries=0

:retry_clean
set /a tries+=1

call flutter clean >nul 2>&1

if exist build (
    if !tries! GEQ 5 goto clean_fail
    timeout /t 1 >nul
    goto retry_clean
)

goto clean_done

:clean_fail
echo [WARNING] Could not fully clean build folder (locked files).

:clean_done
call flutter pub get >nul 2>&1
echo [DONE] Project is ready.

:: =========================
echo.
echo ========================================================
echo   STEP 2: Building Android APK (Release)...
echo ========================================================
echo (Please wait...)

if exist "%APK_FLAG%" del "%APK_FLAG%"

start "" cmd /c "flutter build apk --release && echo success > "%APK_FLAG%" || echo fail > "%APK_FLAG%""

set idx=0

:apk_spinner
set /a idx=(idx + 1) %% 4
if !idx!==0 set "spin=|"
if !idx!==1 set "spin=/"
if !idx!==2 set "spin=-"
if !idx!==3 set "spin=\"

<nul set /p "=Building APK... !spin!!CR!"
ping -n 1 127.0.0.1 >nul

if not exist "%APK_FLAG%" goto apk_spinner

set /p result=<"%APK_FLAG%"
if "%result%"=="fail" (
    echo.
    echo [ERROR] APK build FAILED.
    pause
    exit /b
)

echo.
echo [DONE] Android APK created successfully.

:: Rename APK
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    move /y "build\app\outputs\flutter-apk\app-release.apk" "build\app\outputs\flutter-apk\%NEW_APK_NAME%" >nul
    echo [INFO] APK renamed to: %NEW_APK_NAME%
)

:: =========================
echo.
echo ========================================================
echo   STEP 3: Building Windows Release...
echo ========================================================

if exist "%WIN_FLAG%" del "%WIN_FLAG%"

start "" cmd /c "flutter build windows --release && echo success > "%WIN_FLAG%" || echo fail > "%WIN_FLAG%""

set idx=0

:win_spinner
set /a idx=(idx + 1) %% 4
if !idx!==0 set "spin=|"
if !idx!==1 set "spin=/"
if !idx!==2 set "spin=-"
if !idx!==3 set "spin=\"

<nul set /p "=Building Windows... !spin!!CR!"
ping -n 1 127.0.0.1 >nul

if not exist "%WIN_FLAG%" goto win_spinner

set /p result=<"%WIN_FLAG%"
if "%result%"=="fail" (
    echo.
    echo [ERROR] Windows build FAILED.
    pause
    exit /b
)

echo.
echo [DONE] Windows Release Built.

:: =========================
echo.
echo ========================================================
echo   STEP 4: Signing + Windows Installer + SHA-256
echo ========================================================

if not exist "%ISS_PATH%" (
    echo [ERROR] ISS file not found:
    echo %ISS_PATH%
    pause
    exit /b
)

if not exist "%~dp0scripts\release_windows.ps1" (
    echo [ERROR] Release script not found:
    echo %~dp0scripts\release_windows.ps1
    pause
    exit /b
)

echo [INFO] Signing exe, building installer, signing setup, hashing...

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\release_windows.ps1" -SkipBuild

if errorlevel 1 (
    echo.
    echo [ERROR] Windows release failed (signing / installer / hashes).
    echo         If the cert is missing, run once:
    echo         powershell -ExecutionPolicy Bypass -File scripts\new_codesign_cert.ps1
    pause
    exit /b
)

echo [DONE] Windows Setup signed + SHA256SUMS.txt created.

:: =========================
echo.
echo ========================================================
echo   BUILDS COMPLETED!
echo.
echo   - Android APK: build\app\outputs\flutter-apk\%NEW_APK_NAME%
echo   - Windows EXE: InstallerOutput\SuperNoteSetup.exe (self-signed)
echo   - Checksums : InstallerOutput\SHA256SUMS.txt
echo ========================================================

:: =========================
echo.
echo [INFO] Cleaning temporary flags...

set tries=0

:retry_cleanup
set /a tries+=1

del /f /q "%APK_FLAG%" >nul 2>&1
del /f /q "%WIN_FLAG%" >nul 2>&1

if exist "%APK_FLAG%" goto check_retry
if exist "%WIN_FLAG%" goto check_retry
goto cleanup_done

:check_retry
if !tries! GEQ 5 goto cleanup_fail
timeout /t 1 >nul
goto retry_cleanup

:cleanup_fail
echo [WARNING] Could not delete temp flags (still in use).

:cleanup_done
echo [DONE] Cleanup finished.

echo.
pause