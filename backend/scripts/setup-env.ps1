$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$envFile = Join-Path $projectDir '.env'
$legacyEnvFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.env'
if (Test-Path $envFile) {
    Write-Host '.env da ton tai. Giu nguyen mat khau va khoa JWT.'
    exit 0
}
if (Test-Path $legacyEnvFile) {
    Copy-Item -LiteralPath $legacyEnvFile -Destination $envFile
    Write-Host 'Da sao chep backend/.env cu ve .env tai root. Hay dung docker compose tu thu muc root.'
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
    'GOOGLE_CLIENT_IDS='
    'CORS_ORIGINS=http://localhost:3000,http://localhost:5173'
    'API_PORT=8081'
) | Set-Content -Path $envFile -Encoding ASCII
Write-Host 'Da tao .env. Chay: docker compose up -d --build'
