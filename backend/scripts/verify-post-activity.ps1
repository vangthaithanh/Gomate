param(
 [Parameter(Mandatory)][string]$BaseUrl,
 [Parameter(Mandatory)][string]$Database,
 [Parameter(Mandatory)][string]$StatePath,
 [switch]$VerifyRestart
)
$ErrorActionPreference='Stop'
$uri=[uri]$BaseUrl
if($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -notin @(18095,18096) -or $Database -notin @('gomate_activity_clean','gomate_activity_upgrade')){throw 'Isolated activity databases only'}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../backups'))+[IO.Path]::DirectorySeparatorChar
$StatePath=[IO.Path]::GetFullPath($StatePath)
if(-not $StatePath.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Keep test credentials in ignored backups'}
function Check($value,$message){if(-not $value){throw $message}}
function Sql($query){
 $result=docker compose exec -T postgres psql -U gomate -d $Database -qAt -v ON_ERROR_STOP=1 -c $query
 if($LASTEXITCODE -ne 0){throw 'SQL failed'}
 ($result -join "`n").Trim()
}
function Api($method,$path,$user,$body=$null,$expected=200){
 $p=@{Method=$method;Uri=$BaseUrl.TrimEnd('/')+$path;SkipHttpErrorCheck=$true;TimeoutSec=45}
 if($user){$p.Headers=@{Authorization='Bearer '+$user.token}}
 if($null -ne $body){$p.ContentType='application/json; charset=utf-8';$p.Body=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 12))}
 $response=Invoke-WebRequest @p
 Check ([int]$response.StatusCode -eq $expected) "$method $path expected $expected got $($response.StatusCode)"
 if($response.Content){$response.Content|ConvertFrom-Json}
}
function User {
 $key='activity'+[guid]::NewGuid().ToString('N').Substring(0,14)
 $r=Api POST '/auth/register' $null @{email="$key@example.com";nickname=$key;password='TestPass123!'} 201
 @{id=$r.user.id;token=$r.accessToken;email="$key@example.com"}
}
function Login($user){$r=Api POST '/auth/login' $null @{email=$user.email;password='TestPass123!'};$user.token=$r.accessToken}
function Comment($user,$post,$body,$parent=$null){Api POST "/posts/$post/comments" $user @{clientRequestId=[guid]::NewGuid().ToString();body=$body;parentId=$parent;mediaIds=@()} 201}
Check ((Sql 'SELECT MAX(version::int) FROM flyway_schema_history WHERE success') -eq '23') 'Expected V23'
Check ((Sql "SELECT COUNT(*) FROM pg_indexes WHERE schemaname='public' AND indexname IN ('ix_post_likes_user_created','ix_comments_user_created')") -eq '2') 'Missing activity indexes'
if($VerifyRestart){
 $s=Get-Content -Raw -LiteralPath $StatePath|ConvertFrom-Json -AsHashtable
 Login $s.viewer
 foreach($path in @('liked-posts','saved-posts')){
  $r=Api GET "/me/$path" $s.viewer
  Check (@($r.items.post.id) -contains $s.post) "$path persistence failed"
 }
 $r=Api GET '/me/comments' $s.viewer
 Check (@($r.items.commentId) -contains $s.reply) 'Own reply persistence failed'
 Write-Output 'PASS restart/relogin: likes, saves, own comments persist'
 return
}
$owner=User;$viewer=User;$other=User
$media=[guid]::NewGuid().ToString()
$null=Sql "INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES('$media','$($owner.id)','activity-test','IMAGE','READY','isolated/activity/$media','isolated/activity/${media}_cover','png','image/png',4,2,2)"
$post=Api POST '/posts' $owner @{clientRequestId=[guid]::NewGuid().ToString();caption='Isolated activity test';audience='EVERYONE';mediaIds=@($media);hashtags=@();taggedUserIds=@()} 201
$id=$post.id
$null=Api PUT "/posts/$id/like" $viewer
$null=Api PUT "/posts/$id/save" $viewer
$root=Comment $other $id 'Reference only'
$reply=Comment $viewer $id 'Own reply' $root.commentId
$own=Comment $viewer $id 'Own root'
foreach($path in @('liked-posts','saved-posts')){
 $r=Api GET "/me/$path" $viewer
 Check (@($r.items.post.id) -contains $id) "$path wrong Post identity"
 $entry=@($r.items|Where-Object {$_.post.id -eq $id})[0]
 Check ($entry.post.media[0].thumbnailUrl -like '/posts/*/media/*/thumbnail') 'Unprotected preview URL'
 $r=Api GET "/me/$path" $other
 Check (@($r.items.post.id) -notcontains $id) 'Other actor leaked activity'
}
$r=Api GET '/me/comments?size=1' $viewer
Check ($r.items[0].commentId -eq $own.commentId -and $r.nextCursor) 'Comment newest-first paging failed'
$r=Api GET ('/me/comments?size=1&cursor='+[uri]::EscapeDataString($r.nextCursor)) $viewer
Check ($r.items[0].commentId -eq $reply.commentId -and $r.items[0].parentBody -eq 'Reference only') 'Own reply reference failed'
$null=Api DELETE "/comments/$($root.commentId)" $viewer $null 404
$null=Api PATCH '/users/me/profile' $owner @{isPrivate=$true}
$null=Api PUT "/users/$($owner.id)/follow" $viewer
foreach($path in @('liked-posts','saved-posts','comments')){
 $r=Api GET "/me/$path" $viewer
 Check (@($r.items.post.id) -notcontains $id) 'PENDING exposed private preview'
}
$null=Api GET "/posts/$id/media/$media/thumbnail" $viewer $null 404
$r=Api GET '/users/me/follow-requests' $owner
$pending=@($r.items|Where-Object requesterId -eq $viewer.id)[0]
$null=Api POST "/users/me/follow-requests/$($pending.id)/accept" $owner
$r=Api GET '/me/liked-posts' $viewer
Check (@($r.items.post.id) -contains $id) 'Accepted access did not restore activity'
$null=Api DELETE "/comments/$($own.commentId)" $viewer $null 204
$r=Api GET '/me/comments' $viewer
Check (@($r.items.commentId) -contains $reply.commentId -and @($r.items.commentId) -notcontains $own.commentId) 'Delete changed wrong own comment'
$null=Api DELETE "/posts/$id/like" $viewer
$null=Api DELETE "/posts/$id/save" $viewer
foreach($path in @('liked-posts','saved-posts')){
 $r=Api GET "/me/$path" $viewer
 Check (@($r.items.post.id) -notcontains $id) 'Removed relation remains in activity'
}
$null=Api GET "/posts/$id" $owner
$null=Api GET "/posts/$id" $viewer
$null=Api PUT "/posts/$id/like" $viewer
$null=Api PUT "/posts/$id/save" $viewer
$null=Api GET '/me/reports' $viewer
@{viewer=$viewer;post=$id;reply=$reply.commentId}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding utf8
Write-Output 'PASS PostgreSQL HTTP: JWT scope, real Post IDs, protected paths, own root/reply paging, ownership, privacy PENDING/accepted, unlike/unsave and comment deletion'
