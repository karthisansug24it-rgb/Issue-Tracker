@echo off
title Dtrack Desktop App (Windows)
echo ========================================================
echo Starting Dtrack Windows Desktop Native App...
echo ========================================================
cd /d "%~dp0devtrack_desktop"
flutter run -d windows
pause
