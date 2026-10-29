param(
 [Parameter(Mandatory)][string]$BaseUrl,
 [Parameter(Mandatory)][string]$Database,
 [Parameter(Mandatory)][string]$ApiContainer,
 [Parameter(Mandatory)][string]$StatePath,
 [switch]$VerifyRestart,
 [switch]$LegacyV19,
 [switch]$PinRaceOnly,
 [switch]$CleanupAssets
)
$ErrorActionPreference='Stop'
$uri=[uri]$BaseUrl
if($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -notin @(18088,18089) -or
 $Database -notmatch '^gomate_p1c_(clean|upgrade)$' -or $ApiContainer -notmatch '^gomate-p1c-(clean|upgrade)$') {
 throw 'Isolated P1C test API/database only; never point this script at user data.'
}
$BaseUrl=$BaseUrl.TrimEnd('/')
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../backups'))+[IO.Path]::DirectorySeparatorChar
$StatePath=[IO.Path]::GetFullPath($StatePath)
if(-not $StatePath.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Test token state must stay in ignored backups/'}
$fixtures=Join-Path (Split-Path -Parent $StatePath) $Database
New-Item -ItemType Directory -Path $fixtures -Force | Out-Null
function Check($Value,[string]$Message){if(-not $Value){throw $Message}}
function Sql([string]$Query){$r=docker compose exec -T postgres psql -U gomate -d $Database -qAt -v ON_ERROR_STOP=1 -c $Query; if($LASTEXITCODE -ne 0){throw 'SQL verification failed'}; ($r -join "`n").Trim()}
function Api([string]$Method,[string]$Path,$User,$Body=$null,[int]$Expected=200){
 $p=@{Method=$Method;Uri=$BaseUrl+$Path;SkipHttpErrorCheck=$true;TimeoutSec=60}
 if($User){$p.Headers=@{Authorization='Bearer '+$User.token}}
 if($null -ne $Body){$p.ContentType='application/json; charset=utf-8';$p.Body=[Text.Encoding]::UTF8.GetBytes(($Body|ConvertTo-Json -Depth 12))}
 $r=Invoke-WebRequest @p;Check ([int]$r.StatusCode -eq $Expected) "$Method $Path expected $Expected, got $($r.StatusCode): $($r.Content)"
 if($r.Content){$r.Content|ConvertFrom-Json}
}
function User {
 $key='post'+[guid]::NewGuid().ToString('N').Substring(0,15)
 $r=Api POST '/auth/register' $null @{email="$key@example.com";nickname=$key;password='PostTest123!'} 201
 @{id=$r.user.id;token=$r.accessToken;email="$key@example.com"}
}
function Binary($User,[string]$Path,[int]$Expected=200,[string]$Range=''){
 $h=@{};if($User){$h.Authorization='Bearer '+$User.token};if($Range){$h.Range=$Range}
 $r=Invoke-WebRequest -Uri ($BaseUrl+$Path) -Headers $h -SkipHttpErrorCheck -TimeoutSec 60
 Check ([int]$r.StatusCode -eq $Expected) "Media expected $Expected, got $($r.StatusCode)"
 if($Expected -in @(200,206)){Check (($r.Headers['Cache-Control'] -join '') -match 'no-store') 'Media cache policy missing'}
 return $r
}
function Upload($User,[string]$File,[string]$Kind,[guid]$Id=([guid]::NewGuid()),[int]$Expected=200){
 $client=[Net.Http.HttpClient]::new();$client.Timeout=[TimeSpan]::FromSeconds(180)
 $form=[Net.Http.MultipartFormDataContent]::new()
 $stream=[IO.File]::OpenRead($File)
 try {
  $client.DefaultRequestHeaders.Authorization=[Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$User.token)
  $content=[Net.Http.StreamContent]::new($stream)
  $content.Headers.ContentType=[Net.Http.Headers.MediaTypeHeaderValue]::new($(if($Kind -eq 'VIDEO'){'video/mp4'}else{'image/png'}))
  $form.Add($content,'file',[IO.Path]::GetFileName($File))
  $form.Add([Net.Http.StringContent]::new($Id.ToString()),'uploadId')
  $form.Add([Net.Http.StringContent]::new($Kind),'kind')
  $response=$client.PostAsync("$BaseUrl/posts/media",$form).GetAwaiter().GetResult()
  $text=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
  Check ([int]$response.StatusCode -eq $Expected) "Upload $Kind expected $Expected, got $([int]$response.StatusCode): $text"
  if($Expected -eq 200){$text|ConvertFrom-Json}
 } finally {$form.Dispose();$stream.Dispose();$client.Dispose()}
}
function Publish($User,[string]$Audience,$Ids,$People=@(),[string]$Caption="Đà Lạt 🌸`nDòng hai"){
 $b=@{clientRequestId=[guid]::NewGuid().ToString();caption=$Caption;audience=$Audience;mediaIds=@($Ids);hashtags=@('#ĐàLạt','đàlạt');taggedUserIds=@($People)}
 $post=Api POST '/posts' $User $b 201
 $again=Api POST '/posts' $User $b 201
 Check ($post.id -eq $again.id) 'Retry created duplicate Post'
 Check ($post.caption -ceq $Caption) 'Caption Unicode/newline changed'
 Check (@($post.hashtags).Count -eq 1) 'Hashtag normalization failed'
 Check ($post.media[0].url -notmatch 'cloudinary') 'Provider URL leaked'
 $post
}
if($CleanupAssets) {
 $s=Get-Content -Raw -LiteralPath $StatePath|ConvertFrom-Json -AsHashtable
 $line=Get-Content (Join-Path $PSScriptRoot '../../.env')|Where-Object {$_ -match '^CLOUDINARY_URL='}|Select-Object -First 1
 $cloud=[uri]($line.Substring($line.IndexOf('=')+1).Trim().Trim('"'))
 $credentials=$cloud.UserInfo -split ':',2
 $key=[uri]::UnescapeDataString($credentials[0]);$secret=[uri]::UnescapeDataString($credentials[1])
 $removed=0
 foreach($owner in $s.users) {
  $guid=[guid]::Parse($owner.id)
  $rows=Sql "SELECT public_id,thumbnail_public_id,kind FROM post_media WHERE owner_id='$guid'::uuid"
  foreach($row in ($rows -split "`n" | Where-Object {$_})) {
   $p=$row -split '\|'
   foreach($asset in @(@{id=$p[0];type=if($p[2] -eq 'VIDEO'){'video'}else{'image'}},@{id=$p[1];type='image'})) {
    Check ($asset.id.StartsWith("gomate/posts/$guid/")) 'Unexpected asset outside test owner'
    $params=@{public_id=$asset.id;type='authenticated';timestamp=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}
    $canonical=($params.Keys|Sort-Object|ForEach-Object {"$_=$($params[$_])"}) -join '&'
    $signature=[Convert]::ToHexString([Security.Cryptography.SHA1]::HashData([Text.Encoding]::UTF8.GetBytes($canonical+$secret))).ToLowerInvariant()
    $body=@{}+$params;$body.api_key=$key;$body.signature=$signature
    $result=Invoke-RestMethod -Method Post -Uri "https://api.cloudinary.com/v1_1/$($cloud.Host)/$($asset.type)/destroy" -Body $body -TimeoutSec 40
    Check ($result.result -in @('ok','not found')) 'Test asset cleanup failed'
    $removed++
   }
  }
 }
 Write-Output "PASS cleanup: $removed test-owned authenticated assets/thumbnail operations"
 return
}

function Fixtures {
 docker exec $ApiContainer ffmpeg -nostdin -v error -f lavfi -i color=c=blue:s=64x64:d=1 -frames:v 1 -threads 1 -y /tmp/p1c.png
 docker exec $ApiContainer ffmpeg -nostdin -v error -f lavfi -i testsrc2=s=32x32:r=10 -t 45 -an -c:v libx264 -threads 1 -pix_fmt yuv420p -y /tmp/p1c45.mp4
 docker exec $ApiContainer ffmpeg -nostdin -v error -ss 5 -i /tmp/p1c45.mp4 -t 29 -an -c:v libx264 -threads 1 -y /tmp/p1c29.mp4
 foreach($duration in @('30','30.001')) {
  docker exec $ApiContainer ffmpeg -nostdin -v error -f lavfi -i color=c=blue:s=32x32:r=1000 -t $duration -an -c:v libx264 -preset ultrafast -threads 1 -y "/tmp/p1c$duration.mp4"
  if($LASTEXITCODE){throw 'Boundary fixture generation failed'}
 }
 foreach($name in @('p1c.png','p1c45.mp4','p1c29.mp4','p1c30.mp4','p1c30.001.mp4')) {docker cp "${ApiContainer}:/tmp/$name" (Join-Path $fixtures $name)}
}
function PinRace($Owner,$Ids) {
 foreach($id in $Ids[0..1]) {$null=Api PUT "/posts/$id/pin" $Owner}
 $client=[Net.Http.HttpClient]::new()
 try {
  $client.DefaultRequestHeaders.Authorization=[Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$Owner.token)
  $one=$client.PutAsync("$BaseUrl/posts/$($Ids[2])/pin",$null)
  $two=$client.PutAsync("$BaseUrl/posts/$($Ids[3])/pin",$null)
  $r1=$one.GetAwaiter().GetResult();$r2=$two.GetAwaiter().GetResult()
  $codes=@([int]$r1.StatusCode,[int]$r2.StatusCode)|Sort-Object
  Check (($codes -join ',') -eq '200,422') 'Concurrent pins did not serialize into exactly one success'
  Check ((Sql "SELECT COUNT(*) FROM posts WHERE author_id='$($Owner.id)'::uuid AND pinned_at IS NOT NULL AND deleted_at IS NULL") -eq '3') 'PostgreSQL pin count exceeded 3'
  $r1.Dispose();$r2.Dispose()
 } finally {$client.Dispose()}
}
if($LegacyV19) {
 Check ((Sql "SELECT MAX(version::int) FROM flyway_schema_history") -eq '19') 'Legacy fixture requires untouched V19'
 $s=@{users=@((User),(User),(User),(User),(User));postIds=@()}
 $s|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $StatePath -Encoding utf8
 Fixtures
 $a=$s.users[0]
 $original=Upload $a (Join-Path $fixtures 'p1c45.mp4') VIDEO
 $staged=Upload $a (Join-Path $fixtures 'p1c45.mp4') VIDEO
 $legacy=Publish $a EVERYONE @($original.mediaId)
 $s.legacyPostId=$legacy.id;$s.stagedId=$staged.mediaId
 $s|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $StatePath -Encoding utf8
 Write-Output 'PASS V19 fixture: real 45-second published video plus 45-second unattached staged asset'
 return
}
if(Test-Path -LiteralPath $StatePath) {$s=Get-Content -Raw -LiteralPath $StatePath|ConvertFrom-Json -AsHashtable}
else {$s=@{users=@((User),(User),(User),(User),(User));postIds=@()};$s|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $StatePath -Encoding utf8}
foreach($user in $s.users) {$login=Api POST '/auth/login' $null @{email=$user.email;password='PostTest123!'};$user.token=$login.accessToken}
$a,$b,$c,$d,$e=$s.users
if($VerifyRestart) {
 $list=Api GET "/users/$($a.id)/posts" $a
 Check ($list.items.Count -gt 0) 'Profile lost posts after restart'
 $null=Api GET "/posts/$($s.deletedPostId)" $a $null 404
 $null=Binary $a $s.deletedMediaPath 404
 $null=Api GET "/posts/$($s.postIds[-1])" $e $null 404
 if($s.legacyPostId) {$legacy=Api GET "/posts/$($s.legacyPostId)" $a;$null=Binary $a $legacy.media[0].url 206 'bytes=16-31'}
 Write-Output 'PASS restart persistence: profile, pin/delete/privacy and legacy Range'
 return
}
Check ((Sql "SELECT MAX(version::int) FROM flyway_schema_history") -eq '20') 'Expected V20'
Check ((Sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'") -eq '31') 'Unexpected table'
Fixtures
if($PinRaceOnly) {
 $ids=@()
 foreach($i in 1..4) {$m=Upload $a (Join-Path $fixtures 'p1c.png') IMAGE;$p=Publish $a EVERYONE @($m.mediaId);$ids+=@($p.id)}
 PinRace $a $ids
 Write-Output 'PASS PostgreSQL concurrent HTTP pins: two requests, exactly one 200 and one 422, count stays 3'
 return
}
$probe=docker exec $ApiContainer ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 /tmp/p1c30.001.mp4
Check ([decimal]$probe -eq [decimal]'30.001') 'Expected exact 30001ms input fixture'
$null=Upload $a (Join-Path $fixtures 'p1c30.001.mp4') VIDEO -Expected 422
$exact=Upload $a (Join-Path $fixtures 'p1c30.mp4') VIDEO
Check ($exact.durationMs -eq 30000) '30000ms output was not accepted exactly'
$cut=Upload $a (Join-Path $fixtures 'p1c29.mp4') VIDEO
Check ($cut.durationMs -eq 29000) 'Actual middle clip is not 29 seconds'
$cover=Upload $a (Join-Path $fixtures 'p1c.png') IMAGE
$first=Publish $a EVERYONE @($exact.mediaId,$cover.mediaId,$cut.mediaId)
$s.postIds=@($first.id)
foreach($i in 1..3) {$m=Upload $a (Join-Path $fixtures 'p1c.png') IMAGE;$p=Publish $a EVERYONE @($m.mediaId);$s.postIds+=@($p.id)}
$s|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $StatePath -Encoding utf8
if($s.legacyPostId) {
 $old=Api GET "/posts/$($s.legacyPostId)" $a
 Check ($old.media[0].durationMs -eq 45000) 'Old video duration changed'
 $null=Binary $a $old.media[0].url 206 'bytes=16-31'
 $null=Api POST '/posts' $a @{clientRequestId=[guid]::NewGuid().ToString();caption='Cannot attach old staging';audience='EVERYONE';mediaIds=@($s.stagedId);hashtags=@();taggedUserIds=@()} 422
}
foreach($id in $s.postIds[0..2]) {$p=Api PUT "/posts/$id/pin" $a;Check $p.pinned 'Pin failed'}
$null=Api PUT "/posts/$($s.postIds[3])/pin" $a $null 422
$null=Api PUT "/posts/$($s.postIds[0])/pin" $e $null 404
$all=@();$path="/users/$($a.id)/posts?size=2"
do {$page=Api GET $path $a;Check (-not $page.PSObject.Properties['total']) 'Profile exposes count';$all+=@($page.items);if($page.nextCursor){$path="/users/$($a.id)/posts?size=2&cursor=$([uri]::EscapeDataString($page.nextCursor))"}} while($page.nextCursor)
Check (@($all.id|Select-Object -Unique).Count -eq $all.Count) 'Paging duplicate'
Check (@($all|Where-Object pinned).Count -eq 3) 'Pin limit changed'
$null=Api PUT "/users/$($a.id)/follow" $b
$null=Api PUT "/users/$($a.id)/follow" $c
$null=Api PUT "/users/$($c.id)/follow" $a
$null=Api PATCH '/users/me/profile' $a @{isPrivate=$true}
$pending=Api PUT "/users/$($a.id)/follow" $d
Check $pending.followRequestPending 'Pending relation lost'
foreach($u in @($d,$e)) {$p=Api GET "/users/$($a.id)/posts" $u;Check ($p.items.Count -eq 0 -and -not $p.nextCursor) 'Hidden profile metadata leaked'}
$id=$s.postIds[0]
$p=Api PATCH "/posts/$id/audience" $a @{audience='FRIENDS'}
$null=Binary $b $p.media[0].url 404;$null=Binary $c $p.media[0].url
$p=Api PATCH "/posts/$id/audience" $a @{audience='ONLY_ME'}
$null=Binary $c $p.media[0].thumbnailUrl 404
$p=Api PATCH "/posts/$id/audience" $a @{audience='FOLLOWERS'}
$null=Binary $b $p.media[0].url
$null=Api PATCH '/users/me/profile' $a @{isPrivate=$false}
$p=Api GET "/posts/$id" $e;Check ($p.audience -eq 'EVERYONE') 'ACCOUNT mapping failed'
$null=Api PATCH '/users/me/profile' $a @{isPrivate=$true}
$s.deletedPostId=$id;$s.deletedMediaPath=$p.media[0].url
$null=Api DELETE "/posts/$id" $e $null 404
$null=Api DELETE "/posts/$id" $a $null 204
$null=Api DELETE "/posts/$id" $a $null 204
$null=Binary $a $p.media[0].url 404 'bytes=0-15'
$null=Binary $a $p.media[0].thumbnailUrl 404
$null=Api PUT "/posts/$($s.postIds[3])/pin" $a
$s|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $StatePath -Encoding utf8
Write-Output 'PASS V20: exact 30000/30001ms files, real middle trim, profile paging/permissions, 3 pins, audience, delete/direct Range; V19 long published video preserved where present'

