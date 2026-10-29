param(
 [string]$BaseUrl='http://127.0.0.1:18096/api/v1',
 [string]$Database='gomate_post_notifications_verify',
 [Parameter(Mandatory)][string]$StatePath,
 [switch]$VerifyRestart
)
$ErrorActionPreference='Stop'
$uri=[uri]$BaseUrl
if($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -ne 18096 -or $Database -ne 'gomate_post_notifications_verify') {throw 'Isolated notification verification API/database only'}
$allowed=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../backups'))+[IO.Path]::DirectorySeparatorChar
$StatePath=[IO.Path]::GetFullPath($StatePath)
if(-not $StatePath.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) {throw 'Keep local fixture sessions under ignored backups'}
function Check($ok,$text) {if(-not $ok) {throw $text}}
function Sql($sql) {
 $result=docker compose exec -T postgres psql -U gomate -d $Database -qAt -v ON_ERROR_STOP=1 -c $sql
 Check ($LASTEXITCODE -eq 0) 'Verification SQL failed'
 ($result -join "`n").Trim()
}
function Api($method,$path,$user,$body=$null,$status=200) {
 $args=@{Method=$method;Uri=$BaseUrl+$path;SkipHttpErrorCheck=$true;TimeoutSec=40}
 if($user) {$args.Headers=@{Authorization='Bearer '+$user.token}}
 if($null -ne $body) {$args.ContentType='application/json; charset=utf-8';$args.Body=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 12))}
 $res=Invoke-WebRequest @args
 Check ([int]$res.StatusCode -eq $status) "$method $path expected $status got $($res.StatusCode)"
 if($res.Content) {$res.Content|ConvertFrom-Json}
}
function User {
 $key='pn'+[guid]::NewGuid().ToString('N').Substring(0,18)
 $s=Api POST '/auth/register' $null @{email="$key@example.invalid";nickname=$key;password='TestPass123!'} 201
 @{id=$s.user.id;email="$key@example.invalid";token=$s.accessToken}
}
function Login($u) {$s=Api POST '/auth/login' $null @{email=$u.email;password='TestPass123!'};$u.token=$s.accessToken}
function Inbox($u) {Api GET '/notifications?size=50' $u}
function Comment($u,$post,$parent=$null) {Api POST "/posts/$post/comments" $u @{clientRequestId=[guid]::NewGuid().ToString();body='Verification comment';parentId=$parent;mediaIds=@()} 201}
Check ((Sql 'SELECT MAX(version::int) FROM flyway_schema_history WHERE success') -eq '24') 'Expected unchanged V24'
if($VerifyRestart) {
 $s=Get-Content -Raw -LiteralPath $StatePath|ConvertFrom-Json -AsHashtable
 Login $s.owner;Login $s.actor
 Check ((Inbox $s.owner).total -eq $s.ownerCount) 'Durable Inbox count after restart'
 $n=Api GET "/notifications/$($s.notice)" $s.owner
 Check ($n.isRead -and $n.postId -eq $s.post) 'Read state/JSONB IDs after restart'
 $null=Api PUT "/posts/$($s.post)/like" $s.actor
 Check ((Inbox $s.owner).total -eq $s.ownerCount) 'Relogin Like retry duplicated notification'
 Write-Output 'PASS PostgreSQL restart/relogin: JSONB IDs, Inbox/read persistence, stable Like identity';return
}
$owner=User;$actor=User;$other=User;$media=[guid]::NewGuid().ToString()
$null=Sql "INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES('$media','$($owner.id)','isolated-notification','IMAGE','READY','isolated/notif/$media','isolated/notif/${media}_cover','png','image/png',4,2,2)"
$post=Api POST '/posts' $owner @{clientRequestId=[guid]::NewGuid().ToString();caption='Verification';audience='EVERYONE';mediaIds=@($media);hashtags=@();taggedUserIds=@()} 201
$p=$post.id
1..2|ForEach-Object {$null=Api PUT "/posts/$p/like" $actor}
$first=(Inbox $owner).items[0]
Check ($first.type -eq 'POST_LIKE' -and $first.actorId -eq $actor.id -and $first.postId -eq $p) 'Like notification ID projection'
$null=Api DELETE "/posts/$p/like" $actor;$null=Api PUT "/posts/$p/like" $actor
Check ((Inbox $owner).total -eq 1 -and (Inbox $actor).total -eq 0) 'Like cycle duplicated or notified actor'
$null=Api PUT "/posts/$p/like" $owner
Check ((Inbox $owner).total -eq 1) 'Self Like notified'
$req=@{clientRequestId=[guid]::NewGuid().ToString();body='Root';parentId=$null;mediaIds=@()}
$root=Api POST "/posts/$p/comments" $actor $req 201;$retry=Api POST "/posts/$p/comments" $actor $req 201
Check ($root.id -eq $retry.id -and (Inbox $owner).total -eq 2) 'Comment retry duplicated'
$reply=Comment $other $p $root.id;$nested=Comment $owner $p $reply.id
Check ((Inbox $owner).total -eq 2) 'Reply incorrectly notified Post owner'
Check ((Inbox $actor).items[0].type -eq 'POST_REPLY') 'Reply recipient wrong'
Check ((Inbox $other).items[0].commentId -eq $nested.id) 'Reply-to-reply recipient wrong'
$notice=(Inbox $other).items[0]
$target=Api GET "/notifications/$($notice.id)/post-target" $other
Check ($target.rootCommentId -eq $root.id -and $target.commentAvailable) 'Thread target wrong'
$null=Api GET "/notifications/$($notice.id)" $owner $null 404
$null=Api GET "/notifications/$($notice.id)/post-target" $owner $null 404
$null=Api PATCH "/notifications/$($notice.id)/read" $owner $null 404
$null=Api PATCH '/users/me/profile' $owner @{isPrivate=$true}
$null=Api GET "/notifications/$($notice.id)/post-target" $other $null 404
$null=Api PATCH '/users/me/profile' $owner @{isPrivate=$false}
$null=Api PATCH "/posts/$p/audience" $owner @{audience='ONLY_ME'}
$null=Api GET "/notifications/$($notice.id)/post-target" $other $null 404
$null=Api GET "/posts/$p/media/$media/thumbnail" $other $null 404
$null=Api PATCH "/posts/$p/audience" $owner @{audience='EVERYONE'}
$null=Api DELETE "/comments/$($root.id)" $actor $null 204
$target=Api GET "/notifications/$($notice.id)/post-target" $other
Check (-not $target.commentAvailable -and $target.postId -eq $p) 'Deleted thread target not controlled'
$null=Api PATCH "/notifications/$($first.id)/read" $owner
Check ((Inbox $owner).unreadCount -eq 1) 'Read count not persisted'
Check ((Sql "SELECT COUNT(*) FROM notifications WHERE user_id='$($owner.id)' AND type='POST_LIKE'") -eq '1') 'PostgreSQL uniqueness failed'
@{owner=$owner;actor=$actor;post=$p;notice=$first.id;ownerCount=(Inbox $owner).total}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding utf8
Write-Output 'PASS PostgreSQL HTTP: recipient matrix, Like cycle, self/retry exclusion, JSONB projection, owner scope, privacy/audience/media denial, deleted thread, read ACK'
