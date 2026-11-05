@echo off
rem setup.ps1 pauses internally; the pause here also covers failures before
rem the script even runs (parse errors). Set OPENCODE_SETUP_NO_PAUSE=1 to skip.
set "OPENCODE_SETUP_FROM_CMD=1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
set "RC=%ERRORLEVEL%"
if /i not "%OPENCODE_SETUP_NO_PAUSE%"=="1" pause
exit /b %RC%
