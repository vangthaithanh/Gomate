param(
 [Parameter(Mandatory)][string]$BaseUrl,
 [Parameter(Mandatory)][string]$Database,
 [Parameter(Mandatory)][string]$StatePath,
 [switch]$VerifyRestart
)
$ErrorActionPreference='Stop'
$uri=[uri]$BaseUrl
if($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -notin @(18090,18091) -or
 $Database -notmatch '^gomate_p2_(clean|upgrade)$') {throw 'Isolated P2 fixtures only; never use the application database.'}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../backups'))+[IO.Path]::DirectorySeparatorChar
$StatePath=[IO.Path]::GetFullPath($StatePath)
if(-not $StatePath.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Keep token state under ignored backups/'}
function Check($Value,[string]$Message){if(-not $Value){throw $Message}}
function Sql([string]$Query){
 $r=docker compose exec -T postgres psql -U gomate -d $Database -qAt -v ON_ERROR_STOP=1 -c $Query
 if($LASTEXITCODE -ne 0){throw 'Isolated SQL failed'}
 ($r -join "`n").Trim()
}
function Api([string]$Method,[string]$Path,$User,$Body=$null,[int]$Expected=200){
 $p=@{Method=$Method;Uri=$BaseUrl.TrimEnd('/')+$Path;SkipHttpErrorCheck=$true;TimeoutSec=45}
 if($User){$p.Headers=@{Authorization='Bearer '+$User.token}}
 if($null -ne $Body){$p.ContentType='application/json; charset=utf-8';$p.Body=[Text.Encoding]::UTF8.GetBytes(($Body|ConvertTo-Json -Depth 12))}
 $r=Invoke-WebRequest @p
 Check ([int]$r.StatusCode -eq $Expected) "$Method $Path expected $Expected, got $($r.StatusCode)"
 if($r.Content){$r.Content|ConvertFrom-Json}
}
function User {
 $key='feed'+[guid]::NewGuid().ToString('N').Substring(0,15)
 $r=Api POST '/auth/register' $null @{email="$key@example.com";nickname=$key;password='FeedTest123!'} 201
 @{id=$r.user.id;token=$r.accessToken;email="$key@example.com"}
}
function Login($User){
 $r=Api POST '/auth/login' $null @{email=$User.email;password='FeedTest123!'}
 $User.token=$r.accessToken
}
function Publish($User,[string]$Audience){
 $id=[guid]::NewGuid().ToString()
 # Metadata-only synthetic fixture, no Cloudinary call or production media rewrite.
 $null=Sql "INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES('$id','$($User.id)','p2-test','IMAGE','READY','test/p2/$id','test/p2/${id}_cover','png','image/png',4,2,2)"
 Api POST '/posts' $User @{clientRequestId=[guid]::NewGuid().ToString();caption='Isolated P2 verification';audience=$Audience;mediaIds=@($id);hashtags=@('P2Test');taggedUserIds=@()} 201
}
function Present($User,[long]$Id){
 $page=Api GET '/feed?size=50' $User
 @($page.items.id) -contains $Id
}
function ParallelLike($User,[long]$Id){
 $client=[Net.Http.HttpClient]::new()
 try {
  $client.DefaultRequestHeaders.Authorization=[Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$User.token)
  $tasks=@(1..12|ForEach-Object {$client.PutAsync("$BaseUrl/posts/$Id/like",$null)})
  foreach($task in $tasks){$r=$task.GetAwaiter().GetResult();Check ([int]$r.StatusCode -eq 200) 'Concurrent Like failed';$r.Dispose()}
 } finally {$client.Dispose()}
}
Check ((Sql "SELECT MAX(version::int) FROM flyway_schema_history WHERE success") -eq '21') 'Expected Flyway V21'
if($VerifyRestart){
 $s=Get-Content -Raw -LiteralPath $StatePath|ConvertFrom-Json -AsHashtable
 Login $s.viewer
 $p=Api GET "/posts/$($s.postId)" $s.viewer
 Check ($p.likedByMe -and $p.savedByMe -and $p.likeCount -eq 1) 'Engagement did not persist after restart/login'
 Check (Present $s.viewer $s.postId) 'Restored viewer cannot see eligible Post'
 Write-Output 'PASS restart/login: persistent Like/Save, count=1, Feed eligibility'
 return
}
$a=User;$b=User;$c=User
$posts=@(1..4|ForEach-Object {Publish $a 'EVERYONE'})
$id=[long]$posts[0].id
Check (Present $b $id) 'Global Feed excludes visible non-followed Post'
$first=Api GET '/feed?size=2' $b
Check ($first.items[0].id -eq $posts[3].id -and $first.items[1].id -eq $posts[2].id) 'Newest-first order wrong'
$new=Publish $a 'EVERYONE'
$next=Api GET ('/feed?size=2&cursor='+[uri]::EscapeDataString($first.nextCursor)) $b
Check (@($next.items.id|Where-Object {$_ -in $first.items.id}).Count -eq 0) 'Cursor repeats items'
Check (@($next.items.id) -notcontains $new.id) 'New insert leaked above pagination anchor'
$null=Api GET ('/feed?cursor='+[uri]::EscapeDataString($first.nextCursor)) $a $null 400
$null=Api GET '/feed' $null $null 401
$before=Sql 'SELECT COUNT(*) FROM notifications'
ParallelLike $b $id
1..2|ForEach-Object {$null=Api PUT "/posts/$id/save" $b}
$p=Api GET "/posts/$id" $b
Check ($p.likeCount -eq 1 -and $p.likedByMe -and $p.savedByMe) 'Repeated Like/Save wrong'
$other=Api GET "/posts/$id" $c
Check (-not $other.likedByMe -and -not $other.savedByMe -and $other.likeCount -eq 1) 'Viewer state leaked'
Check ((Sql 'SELECT COUNT(*) FROM notifications') -eq $before) 'Like/Save created notifications'
Check ((Sql "SELECT COUNT(*) FROM post_likes WHERE post_id=$id") -eq '1') 'Duplicate Like rows'
$null=Api PUT "/users/$($a.id)/follow" $c
$null=Api PATCH '/users/me/profile' $a @{isPrivate=$true}
Check (Present $c $id) 'Existing accepted follower lost access'
$null=Api PUT "/users/$($a.id)/follow" $b
Check (-not (Present $b $id)) 'PENDING viewer sees private Feed Post'
$null=Api GET "/posts/$id" $b $null 404
$null=Api PUT "/posts/$id/like" $b $null 404
$null=Api DELETE "/posts/$id/save" $b $null 404
$requests=Api GET '/users/me/follow-requests' $a
$request=@($requests.items|Where-Object {$_.requesterId -eq $b.id})[0]
$null=Api POST "/users/me/follow-requests/$($request.id)/accept" $a
Check (Present $b $id) 'Accepted follower missing from Feed'
$null=Api PUT "/users/$($b.id)/follow" $a
$friend=Publish $a 'FRIENDS'
Check (Present $b $friend.id) 'Mutual follow missing FRIENDS Post'
Check (-not (Present $c $friend.id)) 'One-way follower sees FRIENDS Post'
$only=Publish $a 'ONLY_ME'
Check (Present $a $only.id) 'Owner missing ONLY_ME Post'
Check (-not (Present $b $only.id)) 'Other user sees ONLY_ME'
$null=Api DELETE "/users/$($a.id)/follow" $b
Check (-not (Present $b $id)) 'Unfollow did not revoke private Post'
foreach($private in @($false,$true,$false)){
 $null=Api PATCH '/users/me/profile' $a @{isPrivate=$private}
 Check ((Present $b $id) -eq (-not $private)) 'Privacy toggle not reflected in Feed'
}
$null=Api PATCH "/posts/$($new.id)/audience" $a @{audience='ONLY_ME'}
Check (-not (Present $b $new.id)) 'Audience edit did not revoke Feed Post'
$deleted=$posts[1]
$null=Api DELETE "/posts/$($deleted.id)" $a $null 204
Check (-not (Present $b $deleted.id)) 'Deleted Post stays in Feed'
$null=Api GET $deleted.media[0].thumbnailUrl $a $null 404
@{viewer=$b;postId=$id;owner=$a.id}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding utf8
Write-Output 'PASS PostgreSQL HTTP: global/newest Feed, cursor, Like/Save races, PENDING/accepted/mutual/ONLY_ME, privacy/unfollow/audience/delete, protected denial'
