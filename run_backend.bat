@echo off
title DevTrack Backend Service (Port 8080)
echo ========================================================
echo Starting DevTrack Spring Boot Backend (Port 8080)...
echo ========================================================
cd /d "%~dp0devtrack_backend"
call mvnw.cmd spring-boot:run
pause
