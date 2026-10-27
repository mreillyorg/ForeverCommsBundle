@echo off
setlocal EnableExtensions
title ForeverCommsVoice 0.7.0-beta Installer
pushd "%~dp0"
if errorlevel 1 (
    echo ERROR: Could not locate the extracted installer directory.
    pause
    exit /b 1
)
if not exist "%~dp0..\ForeverCommsVoice.toc" (
    echo ERROR: Could not find the addon files. Use Extract All on the complete ZIP first.
    popd
    pause
    exit /b 1
)
echo Installing ForeverCommsVoice 0.7.0-beta ...
echo Using a process-only execution policy for this installer.
echo Your permanent Windows PowerShell settings will not be changed.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-ForeverCommsVoice.ps1" %*
set "EXITCODE=%ERRORLEVEL%"
popd
echo.
if not "%EXITCODE%"=="0" (
    echo Installation was not completed. See error above.
    echo If a company or school policy blocks unsigned scripts, see install\INSTALL-README.txt
    echo for manual installation instructions.
)
echo Press any key to close this window.
pause >nul
exit /b %EXITCODE%
