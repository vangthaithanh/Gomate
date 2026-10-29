param([string]$BaseUrl = 'http://127.0.0.1:18083/api/v1')
$ErrorActionPreference = 'Stop'
$uri = [uri]$BaseUrl
if ($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -ne 18083) {
    throw 'Use only the disposable verification API with FCM disabled on port 18083.'
}
function Call-Api([string]$Method,[string]$Path,$Session,$Body=$null,[int]$Expected=204) {
    $headers=@{}
    if ($null -ne $Session) { $headers.Authorization='Bearer '+$Session.accessToken }
    $args=@{Method=$Method;Uri=$BaseUrl+$Path;Headers=$headers;SkipHttpErrorCheck=$true;TimeoutSec=10}
    if ($null -ne $Body) { $args.ContentType='application/json';$args.Body=ConvertTo-Json $Body }
    $response=Invoke-WebRequest @args
    if ($response.StatusCode -ne $Expected) { throw "$Method $Path returned $($response.StatusCode), expected $Expected" }
    if ($response.Content) { ConvertFrom-Json $response.Content }
}
function New-User {
    $id=[guid]::NewGuid().ToString('N')
    Call-Api 'POST' '/auth/register' $null @{email="push-$id@example.invalid";password='TestOnly123!'+$id;nickname='push_'+$id.Substring(0,10)} 201
}
$a=New-User
$b=New-User
$installation=[guid]::NewGuid().ToString()
$body=@{installationId=$installation;token='fixture-token-'+[guid]::NewGuid().ToString('N');platform='ANDROID'}
Call-Api 'POST' '/notification-devices' $null $body 401 | Out-Null
Call-Api 'POST' '/notification-devices' $a ($body+@{userId=$b.user.id}) 400 | Out-Null
Call-Api 'POST' '/notification-devices' $a $body | Out-Null
Call-Api 'POST' '/notification-devices' $a $body | Out-Null
$body.token='fixture-rotated-'+[guid]::NewGuid().ToString('N')
Call-Api 'POST' '/notification-devices' $a $body | Out-Null
Call-Api 'POST' '/notification-devices' $b $body | Out-Null
Call-Api 'DELETE' '/notification-devices/current' $a @{installationId=$installation} | Out-Null
Call-Api 'DELETE' '/notification-devices/current' $b @{installationId=$installation} | Out-Null
Call-Api 'DELETE' '/notification-devices/current' $b @{installationId=$installation} | Out-Null
Call-Api 'POST' '/auth/logout' $b | Out-Null
Call-Api 'POST' '/notification-devices' $b $body 401 | Out-Null
[ordered]@{result='PASS';registration='204';unknownOwner='400';unauthenticated='401';repeatRegister='204';rotation='204';rebind='204';unregister='204';revokedSession='401';installationId=$installation;finalOwner=$b.user.id} | ConvertTo-Json
