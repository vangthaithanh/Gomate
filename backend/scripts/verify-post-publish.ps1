param(
 [Parameter(Mandatory)][string]$BaseUrl,
 [Parameter(Mandatory)][string]$Database,
 [Parameter(Mandatory)][string]$ApiContainer,
 [Parameter(Mandatory)][string]$StatePath,
 [switch]$VerifyRestart,
 [switch]$CleanupAssets
)
$ErrorActionPreference='Stop'
$uri=[uri]$BaseUrl
if($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -notin @(18088,18089) -or
 $Database -notmatch '^gomate_p1b_(clean|upgrade)$' -or $ApiContainer -notmatch '^gomate-p1b-(clean|upgrade)$') {
 throw 'Isolated P1B test API/database only; never point this script at user data.'
}
$BaseUrl=$BaseUrl.TrimEnd('/')
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../backups'))+[IO.Path]::DirectorySeparatorChar
$StatePath=[IO.Path]::GetFullPath($StatePath)
if(-not $StatePath.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Test token state must stay in ignored backups/'}
$fixtures=Split-Path -Parent $StatePath
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
if($VerifyRestart){
 $s=Get-Content -Raw -LiteralPath $StatePath|ConvertFrom-Json -AsHashtable
 $owner=$s.users[0];$stranger=$s.users[4]
 foreach($user in @($owner,$stranger)) {
  $login=Api POST '/auth/login' $null @{email=$user.email;password='PostTest123!'}
  $user.token=$login.accessToken
 }
 $p=Api GET "/posts/$($s.postIds[0])" $owner
 Check ($p.audience -eq 'FOLLOWERS') 'Restart lost privacy-based audience'
 $null=Api GET "/posts/$($s.postIds[0])" $stranger $null 404
 $null=Binary $stranger $p.media[0].url 404
 $null=Binary $owner $p.media[0].url
 $null=Binary $stranger $p.media[0].thumbnailUrl 404
 $null=Binary $owner $p.media[0].thumbnailUrl
 Check ((Sql "SELECT COUNT(*) FROM posts WHERE author_id='$($owner.id)'::uuid") -eq '3') 'Post count changed after restart'
 Write-Output 'PASS restart: Post metadata, privacy, protected original/thumbnail authorization persisted'
 return
}

$a=User;$b=User;$c=User;$d=User;$e=User
@{users=@($a,$b,$c,$d,$e);postIds=@()}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $StatePath -Encoding utf8
docker exec $ApiContainer ffmpeg -nostdin -v error -f lavfi -i color=c=blue:s=64x64:d=1 -frames:v 1 -threads 1 -y /tmp/p1b.png
if($LASTEXITCODE -ne 0){throw 'Image fixture generation failed'}
docker exec $ApiContainer ffmpeg -nostdin -v error -f lavfi -i color=c=blue:s=64x64:r=10 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 62 -c:v libx264 -threads 1 -pix_fmt yuv420p -c:a aac -movflags +faststart -y /tmp/p1b-source62.mp4
if($LASTEXITCODE -ne 0){throw 'Video fixture generation failed'}
docker exec $ApiContainer ffmpeg -nostdin -v error -ss 2 -i /tmp/p1b-source62.mp4 -t 59 -c:v libx264 -threads 1 -c:a aac -movflags +faststart -y /tmp/p1b-cut59.mp4
if($LASTEXITCODE -ne 0){throw 'Video fixture trim failed'}
docker exec $ApiContainer ffmpeg -nostdin -v error -i /tmp/p1b-cut59.mp4 -t 2 -c:v libx264 -threads 1 -c:a aac -movflags +faststart -y /tmp/p1b-short2.mp4
if($LASTEXITCODE -ne 0){throw 'Short video fixture generation failed'}
foreach($name in @('p1b.png','p1b-source62.mp4','p1b-cut59.mp4','p1b-short2.mp4')){docker cp "${ApiContainer}:/tmp/$name" (Join-Path $fixtures $name)}
$image=Join-Path $fixtures 'p1b.png';$video=Join-Path $fixtures 'p1b-cut59.mp4'
$null=Upload $a (Join-Path $fixtures 'p1b-source62.mp4') VIDEO -Expected 422
$fake=Join-Path $fixtures 'p1b-invalid.png';[IO.File]::WriteAllText($fake,'not an image')
$null=Upload $a $fake IMAGE -Expected 415
$media=@();$uploadId=[guid]::NewGuid()
for($i=0;$i -lt 12;$i++){
 if($i -eq 0){$r=Upload $a $image IMAGE $uploadId}
 elseif($i%2 -eq 0){$r=Upload $a $image IMAGE}
 else{$r=Upload $a $(if($i -eq 11){$video}else{Join-Path $fixtures 'p1b-short2.mp4'}) VIDEO}
 $media+=$r.mediaId
}
$retry=Upload $a $image IMAGE $uploadId
Check ($retry.mediaId -eq $media[0]) 'Upload retry created another asset row'
$ids=@($media[11..0])
$post=Publish $a EVERYONE $ids @($e.id)
Check ($post.media.Count -eq 12) '12 mixed media missing'
for($i=0;$i -lt 12;$i++){Check ($post.media[$i].id -eq $ids[$i] -and $post.media[$i].sortOrder -eq $i) 'Persisted sort order mismatch'}
$null=Binary $e $post.media[0].url
$null=Binary $null $post.media[0].url 401
$range=Binary $a $post.media[0].url 206 'bytes=0-15';Check (($range.Headers['Content-Range'] -join '') -match '^bytes 0-15/') 'Video range unsupported'
$cloudLine=Get-Content (Join-Path $PSScriptRoot '../../.env')|Where-Object {$_ -match '^CLOUDINARY_URL='}|Select-Object -First 1
$cloudName=([uri]($cloudLine.Substring($cloudLine.IndexOf('=')+1).Trim().Trim('"'))).Host
$row=(Sql "SELECT public_id,format,kind,thumbnail_public_id FROM post_media WHERE id='$($ids[0])'::uuid") -split '\|'
$resource=if($row[2] -eq 'VIDEO'){'video'}else{'image'}
foreach($unsigned in @("https://res.cloudinary.com/$cloudName/$resource/authenticated/$($row[0]).$($row[1])","https://res.cloudinary.com/$cloudName/image/authenticated/$($row[3]).jpg")){
 $raw=Invoke-WebRequest -Uri $unsigned -SkipHttpErrorCheck -TimeoutSec 30
 Check ([int]$raw.StatusCode -in @(401,403)) 'Unsigned Cloudinary Post original/thumbnail leaked'
}
$null=Api PUT "/users/$($a.id)/follow" $b
$null=Api PUT "/users/$($a.id)/follow" $c
$null=Api PUT "/users/$($c.id)/follow" $a
$null=Api PATCH '/users/me/profile' $a @{isPrivate=$true}
$pending=Api PUT "/users/$($a.id)/follow" $d
Check ($pending.followRequestPending -and -not $pending.followingByMe) 'Private request did not remain pending'
foreach($user in @($b,$c)){$null=Api GET "/posts/$($post.id)" $user;$null=Binary $user $post.media[0].url}
foreach($user in @($d,$e)){$null=Api GET "/posts/$($post.id)" $user $null 404;$null=Binary $user $post.media[0].url 404;$null=Binary $user $post.media[0].thumbnailUrl 404}
$friendAsset=Upload $a $image IMAGE
$friendPost=Publish $a FRIENDS @($friendAsset.mediaId)
$null=Binary $c $friendPost.media[0].url;$null=Binary $b $friendPost.media[0].url 404
$ownAsset=Upload $a $image IMAGE
$ownPost=Publish $a ONLY_ME @($ownAsset.mediaId) @($c.id)
$null=Binary $a $ownPost.media[0].url;$null=Binary $c $ownPost.media[0].url 404
$null=Api PATCH '/users/me/profile' $a @{isPrivate=$false}
$public=Api GET "/posts/$($post.id)" $e
Check ($public.audience -eq 'EVERYONE') 'PUBLIC switch did not restore effective audience'
$null=Binary $e $post.media[0].url
$null=Api PATCH '/users/me/profile' $a @{isPrivate=$true}
$null=Binary $e $post.media[0].url 404
@{users=@($a,$b,$c,$d,$e);postIds=@($post.id,$friendPost.id,$ownPost.id)}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $StatePath -Encoding utf8
Check ((Sql "SELECT COUNT(*) FROM flyway_schema_history WHERE success=true") -eq '19') 'Unexpected Flyway history'
Check ((Sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'") -eq '31') 'Unexpected tables outside P1B'
Write-Output 'PASS real ffprobe/Cloudinary upload, 62s rejection, 59s output, 12 mixed media, order, idempotency, all audiences, privacy switches, binary/thumbnail/Range gates'
