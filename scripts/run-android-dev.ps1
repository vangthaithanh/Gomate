param(
  [string]$DeviceId = "",
  [string]$HostIp = "",
  [int]$ApiPort = 8080,
  [switch]$InstallOnly,
  [switch]$NoDockerStart,
  [string]$ApplicationId = "com.example.gomate"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Require-Command {
  param([string]$Name)
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) {
    throw "Khong tim thay lenh '$Name' trong PATH."
  }
  return $command.Source
}

function Find-Adb {
  $defaultAdb = Join-Path $env:LOCALAPPDATA "Android\sdk\platform-tools\adb.exe"
  if (Test-Path $defaultAdb) {
    return $defaultAdb
  }

  $adb = Get-Command adb -ErrorAction SilentlyContinue
  if ($adb) {
    return $adb.Source
  }

  throw "Khong tim thay adb. Hay cai Android SDK Platform Tools hoac them adb vao PATH."
}

function Get-ConnectedDevice {
  param(
    [string]$AdbPath,
    [string]$RequestedDeviceId
  )

  $lines = & $AdbPath devices | Select-Object -Skip 1
  $devices = @(
    $lines |
      Where-Object { $_ -match "\tdevice$" } |
      ForEach-Object { ($_ -split "\s+")[0] }
  )

  if ($RequestedDeviceId) {
    if ($devices -notcontains $RequestedDeviceId) {
      $known = if ($devices.Count -gt 0) { $devices -join ", " } else { "(khong co device nao)" }
      throw "Khong thay Android device '$RequestedDeviceId'. Device dang ket noi: $known"
    }
    return $RequestedDeviceId
  }

  if ($devices.Count -eq 0) {
    throw "Khong thay Android device nao. Hay bat USB debugging va kiem tra 'adb devices'."
  }

  if ($devices.Count -gt 1) {
    throw "Dang co nhieu Android device: $($devices -join ', '). Hay chay lai voi -DeviceId <id>."
  }

  return $devices[0]
}

function Get-HostLanIp {
  param([string]$ExplicitHostIp)

  if ($ExplicitHostIp) {
    return $ExplicitHostIp
  }

  $virtualNamePattern = "vEthernet|WSL|Loopback|Docker|Hyper-V|VMware|VirtualBox|Bluetooth"
  $routes = @(Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object RouteMetric)

  foreach ($route in $routes) {
    $adapter = Get-NetAdapter -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue
    if (-not $adapter -or $adapter.Status -ne "Up") {
      continue
    }
    if ($adapter.Name -match $virtualNamePattern -or $adapter.InterfaceDescription -match $virtualNamePattern) {
      continue
    }

    $ip = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -notmatch "^(127\.|169\.254\.)" } |
      Select-Object -First 1
    if ($ip) {
      return $ip.IPAddress
    }
  }

  $fallback = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
      $_.IPAddress -notmatch "^(127\.|169\.254\.)" -and
      $_.InterfaceAlias -notmatch $virtualNamePattern
    } |
    Select-Object -First 1

  if ($fallback) {
    return $fallback.IPAddress
  }

  throw "Khong tu dong tim duoc IPv4 LAN cua PC. Chay lai voi -HostIp <IP-LAN-cua-PC>."
}

Require-Command "flutter" | Out-Null
$adbPath = Find-Adb
$device = Get-ConnectedDevice -AdbPath $adbPath -RequestedDeviceId $DeviceId

if (-not $NoDockerStart) {
  Write-Host "Starting Docker services..."
  docker compose -f .\backend\compose.yaml --env-file .\backend\.env up -d
}

$healthUrl = "http://localhost:$ApiPort/api/v1/health"
try {
  $health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 8
  Write-Host "Backend health on host: $($health.status)"
} catch {
  Write-Warning "Chua goi duoc $healthUrl. Hay kiem tra docker compose ps/logs neu app van bao loi ket noi."
}

$lanIp = Get-HostLanIp -ExplicitHostIp $HostIp
$apiBaseUrl = "http://${lanIp}:$ApiPort/api/v1"
$fallbackUrls = @(
  $apiBaseUrl,
  "http://127.0.0.1:$ApiPort/api/v1",
  "http://10.0.2.2:$ApiPort/api/v1"
)
$apiBaseUrls = $fallbackUrls -join ","

Write-Host "Android device: $device"
Write-Host "LAN API URL: $apiBaseUrl"

try {
  & $adbPath -s $device reverse "tcp:$ApiPort" "tcp:$ApiPort" | Out-Host
  Write-Host "ADB reverse fallback:"
  & $adbPath -s $device reverse --list | Out-Host
} catch {
  Write-Warning "Khong cau hinh duoc adb reverse. App van se uu tien LAN API URL."
}

if ($InstallOnly) {
  Write-Host "Building debug APK with API_BASE_URLS=$apiBaseUrls"
  flutter build apk --debug "--dart-define=API_BASE_URLS=$apiBaseUrls"

  $apkPath = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-debug.apk"
  Write-Host "Installing $apkPath"
  & $adbPath -s $device install -r $apkPath | Out-Host

  Write-Host "Launching $ApplicationId"
  & $adbPath -s $device shell monkey -p $ApplicationId -c android.intent.category.LAUNCHER 1 | Out-Host
} else {
  Write-Host "Running Flutter with API_BASE_URLS=$apiBaseUrls"
  flutter run -d $device "--dart-define=API_BASE_URLS=$apiBaseUrls"
}
