$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

Set-Location $PSScriptRoot

# Tự động khởi chạy EduVault Auth Claim Microservice (Port 5055) nếu chưa chạy
$authPortOpen = $false
try {
    $tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port 5055 -WarningAction SilentlyContinue
    $authPortOpen = $tcp.TcpTestSucceeded
} catch {}

$authJob = $null
if (-not $authPortOpen) {
    Write-Host "[INFO] Khoi dong EduVault Auth Claim Microservice (Port 5055) chay nen..." -ForegroundColor Yellow
    $authJob = Start-Job -ScriptBlock {
        param($workDir)
        Set-Location $workDir
        node .\scripts\auth_claim_server.js
    } -ArgumentList $PSScriptRoot
    Write-Host "[OK] Auth Claim Microservice da chay nen tai http://0.0.0.0:5055" -ForegroundColor Green
} else {
    Write-Host "[OK] Auth Claim Microservice da dang hoat dong tren cong 5055." -ForegroundColor Green
}

try {
    firebase emulators:start --only storage, ui --import=.firebase_emulator_data --export-on-exit
} finally {
    if ($authJob) {
        Stop-Job $authJob -ErrorAction SilentlyContinue | Out-Null
        Remove-Job $authJob -ErrorAction SilentlyContinue | Out-Null
    }
}