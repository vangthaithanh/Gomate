param([string]$BaseUrl = 'http://localhost:8080')
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
function Invoke-Api([string]$Method, [string]$Path, $Body = $null, [string]$Token = '') {
    $params = @{ Method = $Method; Uri = "$BaseUrl$Path" }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json; charset=utf-8'
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 6))
    }
    if ($Token) { $params.Headers = @{ Authorization = "Bearer $Token" } }
    Invoke-RestMethod @params
}
$health = Invoke-Api 'GET' '/health'
if ($health.status -ne 'UP') { throw 'Health check failed' }
Write-Host 'OK: Backend dang chay.'
$suffix = [Guid]::NewGuid().ToString('N').Substring(0, 12)
$password = [Guid]::NewGuid().ToString('N')
$body = @{ email = "test-$suffix@example.com"; password = $password; nickname = "test_$suffix" }
$registered = Invoke-Api 'POST' '/api/v1/auth/register' $body
if (-not $registered.accessToken) { throw 'Register failed' }
Write-Host 'OK: Dang ky + tao ho so, cai dat va phien.'
# Thu hoi phien dang ky truoc khi kiem tra phien dang nhap.
Invoke-Api 'POST' '/api/v1/auth/logout' $null $registered.accessToken | Out-Null
$login = Invoke-Api 'POST' '/api/v1/auth/login' @{ email = $body.email; password = $password }
$profile = Invoke-Api 'GET' '/api/v1/users/me' $null $login.accessToken
if ($profile.email -ne $body.email) { throw 'Profile mismatch' }
$rotated = Invoke-Api 'POST' '/api/v1/auth/refresh' @{ refreshToken = $login.refreshToken }
if ($rotated.refreshToken -eq $login.refreshToken) { throw 'Refresh was not rotated' }
Invoke-Api 'POST' '/api/v1/auth/logout' $null $rotated.accessToken | Out-Null
Write-Host 'OK: Dang nhap, ho so, refresh va dang xuat.'
Write-Host "Tai khoan test duoc tao: $($body.email)"
Write-Host 'Google/Firebase can thu tren app Android da cau hinh Firebase.'
