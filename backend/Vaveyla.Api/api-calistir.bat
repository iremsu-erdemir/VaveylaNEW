@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Vaveyla.Api — http://localhost:5142 (Swagger)
dotnet run --launch-profile http
pause
