@echo off
rem Local release build, mirroring what BigWigsMods/packager produces on GitHub.
rem Output goes to .release\ and is checked against the same contract CI applies.
rem Pass -Source for the installer-bearing source archives instead.
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0package.ps1" %*
if errorlevel 1 (
  echo.
  echo Packaging failed. Check the errors above.
  pause
  exit /b 1
)
echo.
echo Release archive written to the .release folder.
pause
