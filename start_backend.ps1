# Backend API'yi baslat
Set-Location "$PSScriptRoot\backend\Vaveyla.Api"
Write-Host "Backend baslatiliyor (http://localhost:5142)..." -ForegroundColor Green
Write-Host "Swagger: http://localhost:5142/swagger" -ForegroundColor Cyan
dotnet run
