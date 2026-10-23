@echo off
title Dtrack Backend Service (Port 8080)
echo ========================================================
echo Starting Dtrack Spring Boot Backend (Port 8080)...
echo ========================================================
cd /d "%~dp0devtrack_backend"
call mvnw.cmd spring-boot:run
pause
