@echo off
setlocal DisableDelayedExpansion

rem Optional: a custom Spotify install directory.
set "SPOTIFY_PATH=%~1"
if /I "%~1"=="-SpotifyPath" set "SPOTIFY_PATH=%~2"
if "%SPOTIFY_PATH%"=="" set "SPOTIFY_PATH=%APPDATA%\Spotify"
if "%SPOTIFY_PATH:~-1%"=="\" set "SPOTIFY_PATH=%SPOTIFY_PATH:~0,-1%"

if not exist "%SPOTIFY_PATH%\Spotify.exe" (
    echo Spotify was not found at "%SPOTIFY_PATH%".
    echo Usage: Uninstall.bat "C:\path\to\Spotify"
    goto :failed
)

tasklist /FI "IMAGENAME eq Spotify.exe" 2>NUL | find /I "Spotify.exe" >NUL
if not errorlevel 1 (
    echo Please close Spotify before running the uninstaller.
    goto :failed
)

set "RESTORE_FAILED=0"
call :restore "chrome_elf.dll"
call :restore "Spotify.dll"
call :restore "Spotify.exe"
call :restore_xpui
call :restore_locales

if "%RESTORE_FAILED%"=="1" (
    echo Some files could not be restored.
    goto :failed
)

set "DEFENDER_FAILED=0"
call :cleanup_defender
if "%DEFENDER_FAILED%"=="1" (
    echo Patch removed, but Microsoft Defender exclusions could not be removed.
    echo Run Uninstall.bat as administrator to remove them.
    goto :failed
)

if exist "%temp%\SpotX_Temp*" (
    for /d %%i in ("%temp%\SpotX_Temp*") do (
        rd /s/q "%%i" > NUL 2>&1
    )
)

echo Patch successfully removed
pause
exit /b 0

:restore
if not exist "%SPOTIFY_PATH%\%~1.bak" exit /b 0
del /f /q "%SPOTIFY_PATH%\%~1" >NUL 2>&1
move /y "%SPOTIFY_PATH%\%~1.bak" "%SPOTIFY_PATH%\%~1" >NUL 2>&1
if errorlevel 1 (
    echo Failed to restore %~1
    set "RESTORE_FAILED=1"
)
exit /b 0

:restore_xpui
if not exist "%SPOTIFY_PATH%\Apps\xpui.bak" exit /b 0
del /f /q "%SPOTIFY_PATH%\Apps\xpui.spa" >NUL 2>&1
move /y "%SPOTIFY_PATH%\Apps\xpui.bak" "%SPOTIFY_PATH%\Apps\xpui.spa" >NUL 2>&1
if errorlevel 1 (
    echo Failed to restore Apps\xpui.spa
    set "RESTORE_FAILED=1"
)
exit /b 0

:restore_locales
if not exist "%SPOTIFY_PATH%\locales.bak" exit /b 0
if exist "%SPOTIFY_PATH%\locales" rd /s /q "%SPOTIFY_PATH%\locales" >NUL 2>&1
move /y "%SPOTIFY_PATH%\locales.bak" "%SPOTIFY_PATH%\locales" >NUL 2>&1
if exist "%SPOTIFY_PATH%\locales.bak" (
    echo Failed to restore locales
    set "RESTORE_FAILED=1"
)
exit /b 0

:cleanup_defender
rem Only exclusions recorded by the current installer can be removed.
set "SPOTX_DEFENDER_RECORD=%LOCALAPPDATA%\SpotX\defender-exclusions.txt"
if not exist "%SPOTX_DEFENDER_RECORD%" exit /b 0

set "SPOTX_DEFENDER_CLEANUP=$p=$env:SPOTX_DEFENDER_RECORD; if (Test-Path -LiteralPath $p) { $paths=@(Get-Content -LiteralPath $p | Where-Object { $_.Trim() }); if ($paths.Count -gt 0) { Remove-MpPreference -ExclusionPath $paths -ErrorAction Stop }; Remove-Item -LiteralPath $p -Force }"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($env:SPOTX_DEFENDER_CLEANUP)); $proc = Start-Process -FilePath powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-EncodedCommand',$encoded); exit $proc.ExitCode"
if errorlevel 1 set "DEFENDER_FAILED=1"
exit /b 0

:failed
echo.
echo Uninstall did not complete.
pause
exit /b 1
