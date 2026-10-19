@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0package.ps1" %*
if errorlevel 1 (
  echo Packaging failed. Check the errors above.
  pause
  exit /b 1
)
echo.
echo Release packages were written to the dist folder.
pause
