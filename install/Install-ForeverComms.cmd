@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-ForeverComms.ps1" %*
if errorlevel 1 (
  echo.
  echo Installation failed. Existing addons were restored where possible.
  pause
  exit /b 1
)
echo.
echo Installation complete. Restart WoW or type /reload.
pause
