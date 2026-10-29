$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectDir '.env'
if (Test-Path $envFile) {
    Write-Host '.env da ton tai. Giu nguyen mat khau va khoa JWT.'
    exit 0
}
function New-RandomHex([int]$length) {
    $bytes = New-Object byte[] $length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}
@(
    "DB_PASSWORD=$(New-RandomHex 24)"
    "JWT_SECRET=$(New-RandomHex 48)"
    'FIREBASE_ENABLED=false'
    'FIREBASE_PROJECT_ID='
    'CORS_ORIGINS=http://localhost:3000,http://localhost:5173'
) | Set-Content -Path $envFile -Encoding ASCII
Write-Host 'Da tao .env. Chay: docker compose up -d --build'
