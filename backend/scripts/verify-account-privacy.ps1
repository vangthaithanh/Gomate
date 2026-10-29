param(
    [Parameter(Mandatory=$true)][string]$BaseUrl,
    [Parameter(Mandatory=$true)][string]$StatePath,
    [switch]$VerifyPersistence
)
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$uri = [uri]$BaseUrl
if ($uri.Host -notin @('127.0.0.1','localhost') -or $uri.Port -notin @(18088,18089)) {
    throw 'Use only isolated P1A test APIs on localhost:18088/18089, never the main API.'
}
$backupRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../backups')) + [IO.Path]::DirectorySeparatorChar
$StatePath = [IO.Path]::GetFullPath($StatePath)
if (-not $StatePath.StartsWith($backupRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'StatePath contains temporary test tokens and must stay in ignored backups/.'
}

function Assert-That($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Call-Api([string]$Method, [string]$Path, $User, $Body=$null, [int]$Expected=200) {
    $params = @{ Method=$Method; Uri="$BaseUrl$Path"; SkipHttpErrorCheck=$true; TimeoutSec=30 }
    if ($User) { $params.Headers = @{ Authorization="Bearer $($User.token)" } }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json; charset=utf-8'
        $params.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 12))
    }
    $response = Invoke-WebRequest @params
    Assert-That ($response.StatusCode -eq $Expected) "$Method $Path expected $Expected, got $($response.StatusCode)"
    if ($response.Content) { return $response.Content | ConvertFrom-Json }
}
function Register-User([string]$Label) {
    $nickname = 'p1a' + $Label + ([guid]::NewGuid().ToString('N').Substring(0,10))
    $session = Call-Api POST '/auth/register' $null @{email="$nickname@example.com";password='PrivacyTest123!';nickname=$nickname} 201
    return @{id=$session.user.id;token=$session.accessToken;email="$nickname@example.com";nickname=$nickname}
}
function Set-Privacy($User, [bool]$Value) {
    $profile = Call-Api PATCH '/users/me/profile' $User @{isPrivate=$Value}
    Assert-That ($profile.isPrivate -eq $Value) 'Privacy response mismatch'
}

if ($VerifyPersistence) {
    $state = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json -AsHashtable
    $a=$state.a; $b=$state.b; $c=$state.c
    $profile=Call-Api GET '/users/me/profile' $a
    Assert-That ($profile.isPrivate -eq $true) 'Private setting lost after restart'
    $edge=Call-Api GET "/users/$($a.id)/relationship" $b
    Assert-That ($edge.followingByMe -and $edge.mutualFriend) 'Accepted mutual edge lost after restart'
    $inbox=Call-Api GET '/users/me/follow-requests' $a
    Assert-That (@($inbox.items).Count -eq 1) 'Pending request lost after restart'
    Assert-That ($inbox.items[0].requesterId -eq $c.id) 'Wrong pending request owner'
    $login=Call-Api POST '/auth/login' $null @{email=$a.email;password='PrivacyTest123!'}
    Assert-That ($login.user.isPrivate -eq $true) 'Login did not reload persisted privacy'
    Write-Output 'PASS restart persistence: privacy, accepted followers, pending request, Auth login'
    return
}

$a=Register-User a; $b=Register-User b; $c=Register-User c
$public=Call-Api PUT "/users/$($a.id)/follow" $c
Assert-That ($public.followingByMe) 'Public follow should be immediate'
Set-Privacy $a $true
$kept=Call-Api GET "/users/$($a.id)/relationship" $c
Assert-That ($kept.followingByMe) 'Existing follower was removed'
$pending=Call-Api PUT "/users/$($a.id)/follow" $b
Assert-That ($pending.followRequestPending -and -not $pending.followingByMe) 'Private follow not PENDING'
$null=Call-Api PUT "/users/$($a.id)/follow" $b
$queue=Call-Api GET '/users/me/follow-requests' $a
Assert-That ($queue.total -eq 1) 'Duplicate pending request'
$request=$queue.items[0].id
$null=Call-Api POST "/users/me/follow-requests/$request/accept" $c $null 404
$null=Call-Api GET "/users/$($a.id)/followers" $b $null 403
$null=Call-Api POST "/users/me/follow-requests/$request/reject" $a
$null=Call-Api PUT "/users/$($a.id)/follow" $b
$queue=Call-Api GET '/users/me/follow-requests' $a
$request=$queue.items[0].id
$null=Call-Api DELETE "/users/$($a.id)/follow" $b
$null=Call-Api POST "/users/me/follow-requests/$request/accept" $a $null 409
$null=Call-Api PUT "/users/$($a.id)/follow" $b
$queue=Call-Api GET '/users/me/follow-requests' $a
$request=$queue.items[0].id
$null=Call-Api POST "/users/me/follow-requests/$request/accept" $a
$null=Call-Api POST "/users/me/follow-requests/$request/accept" $a
$mutual=Call-Api PUT "/users/$($b.id)/follow" $a
Assert-That ($mutual.mutualFriend) 'Accepted follow did not support real mutual friendship'
$null=Call-Api GET "/users/$($a.id)/followers" $b
Set-Privacy $a $false
Set-Privacy $a $true
$kept=Call-Api GET "/users/$($a.id)/relationship" $b
Assert-That ($kept.mutualFriend) 'Visibility toggle lost accepted follower'
$null=Call-Api DELETE "/users/$($a.id)/follow" $c
$null=Call-Api PUT "/users/$($a.id)/follow" $c
Set-Privacy $a $false
$stillPending=Call-Api GET "/users/$($a.id)/relationship" $c
Assert-That ($stillPending.followRequestPending -and -not $stillPending.followingByMe) 'Toggle auto-accepted pending'
Set-Privacy $a $true
@{a=$a;b=$b;c=$c} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding utf8
Write-Output 'PASS PostgreSQL API: PUBLIC, PRIVATE, duplicate, owner-only, reject/cancel/accept, visibility preservation'
Write-Output 'Test fixture credentials saved only in the ignored StatePath for restart verification.'
