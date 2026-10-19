@echo off
rem Run every offline Lua harness in the suite. Thin launcher only: the runner
rem itself is tools/run_tests.py, so there is one implementation to maintain.
rem Needs Python 3 and a Lua 5.1 interpreter. Set LUA51 to pick a specific one.
setlocal
python "%~dp0tools\run_tests.py" %*
if errorlevel 1 (
  echo.
  echo Harness failures above. Nothing was packaged.
  pause
  exit /b 1
)
echo.
echo All harnesses passed.
pause
