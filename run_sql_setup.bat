@echo off
title DevTrack Database Setup (setup_teammate.sql)
echo ========================================================
echo Applying setup_teammate.sql to PostgreSQL...
echo ========================================================
cd /d "%~dp0"

:: Check if psql is in PATH, if not look in common PostgreSQL installation paths
where psql >nul 2>nul
if %ERRORLEVEL% neq 0 (
    if exist "C:\Program Files\PostgreSQL\18\bin\psql.exe" (
        set "PATH=C:\Program Files\PostgreSQL\18\bin;%PATH%"
    ) else if exist "C:\Program Files\PostgreSQL\17\bin\psql.exe" (
        set "PATH=C:\Program Files\PostgreSQL\17\bin;%PATH%"
    ) else if exist "C:\Program Files\PostgreSQL\16\bin\psql.exe" (
        set "PATH=C:\Program Files\PostgreSQL\16\bin;%PATH%"
    ) else if exist "C:\Program Files\PostgreSQL\15\bin\psql.exe" (
        set "PATH=C:\Program Files\PostgreSQL\15\bin;%PATH%"
    )
)

:: Default database connection settings
set DB_NAME=issuetracker
set DB_USER=postgres
set DB_HOST=localhost
set DB_PORT=5432
set DB_PASSWORD=

:: Load database settings from .env file if it exists
if exist ".env" (
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        if "%%A"=="DB_NAME" set "DB_NAME=%%B"
        if "%%A"=="DB_USERNAME" set "DB_USER=%%B"
        if "%%A"=="DB_HOST" set "DB_HOST=%%B"
        if "%%A"=="DB_PORT" set "DB_PORT=%%B"
        if "%%A"=="DB_PASSWORD" set "DB_PASSWORD=%%B"
    )
)

if defined DB_PASSWORD (
    set "PGPASSWORD=%DB_PASSWORD%"
)

echo Target Database: %DB_NAME% on %DB_HOST%:%DB_PORT% (User: %DB_USER%)
if not defined DB_PASSWORD (
    echo If prompted, enter your PostgreSQL superuser password.
)
echo.

:: Ensure the database exists
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d postgres -c "CREATE DATABASE %DB_NAME%;" 2>nul

:: Apply setup_teammate.sql
psql -h %DB_HOST% -p %DB_PORT% -U %DB_USER% -d %DB_NAME% -f setup_teammate.sql

if %ERRORLEVEL% equ 0 (
    echo.
    echo ========================================================
    echo [SUCCESS] Database setup and seed data applied successfully!
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo [ERROR] Script execution failed. Check output above.
    echo Tip: Make sure DB_PASSWORD in .env matches your PostgreSQL password.
    echo ========================================================
)
pause
