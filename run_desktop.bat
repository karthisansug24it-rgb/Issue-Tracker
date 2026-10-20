@echo off
title DevTrack Desktop App (Windows)
echo ========================================================
echo Starting DevTrack Windows Desktop Native App...
echo ========================================================
cd /d "%~dp0devtrack_desktop"
flutter run -d windows
pause
