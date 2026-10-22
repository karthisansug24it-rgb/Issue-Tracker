@echo off
title DevTrack Web (Port 3000)
echo ========================================================
echo Starting DevTrack Web Frontend on Fixed Port 3000...
echo Preserves session credentials and localStorage across restarts!
echo ========================================================
cd /d "%~dp0devtrack_desktop"
flutter run -d chrome --web-port=3000
pause
