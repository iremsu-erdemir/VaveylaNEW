@echo off
chcp 65001 >nul
set "ROOT=%~dp0"
cd /d "%ROOT%"

echo.
echo  Vaveyla — geliştirme başlatıcı
echo  ------------------------------
echo  [1] Backend API (ASP.NET, http://0.0.0.0:5142 — Swagger)
echo  [2] Flutter uygulaması (bu klasörde flutter run)
echo  [3] Backend yeni pencerede + bu pencerede Flutter bilgisi
echo  [0] Çıkış
echo.
set /p SEC="Seçiminiz (0-3): "

if "%SEC%"=="1" goto backend
if "%SEC%"=="2" goto flutter
if "%SEC%"=="3" goto both
if "%SEC%"=="0" goto end
goto end

:backend
echo.
echo SQL Server bağlantısı ve appsettings.json kontrol edin.
cd /d "%ROOT%backend\Vaveyla.Api"
dotnet run --launch-profile http
goto end

:flutter
cd /d "%ROOT%"
where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter PATH'te yok. SDK kurulumunu kontrol edin.
  pause
  goto end
)
flutter run
goto end

:both
start "Vaveyla API" "%ROOT%backend\Vaveyla.Api\api-calistir.bat"
echo.
echo Backend ayrı pencerede açıldı. Flutter için bu klasörde: flutter run
pause
goto end

:end
