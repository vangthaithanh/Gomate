param(
 [Parameter(Mandatory)][string]$BaseUrl,
 [Parameter(Mandatory)][string]$Database,
 [Parameter(Mandatory)][string]$StatePath,
 [switch]$VerifyRestart
)
$ErrorActionPreference='Stop'
$uri=[uri]$BaseUrl
if($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -notin @(18092,18093) -or $Database -notmatch '^gomate_p3_(clean|upgrade)$'){throw 'Isolated P3 databases only'}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../backups'))+[IO.Path]::DirectorySeparatorChar
$StatePath=[IO.Path]::GetFullPath($StatePath)
if(-not $StatePath.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Keep credentials under ignored backups'}
function Check($v,$message){if(-not $v){throw $message}}
function Sql($q){$r=docker compose exec -T postgres psql -U gomate -d $Database -qAt -v ON_ERROR_STOP=1 -c $q;if($LASTEXITCODE -ne 0){throw 'SQL failed'};($r -join "`n").Trim()}
function Api($method,$path,$u,$body=$null,$expected=200){
 $p=@{Method=$method;Uri=$BaseUrl.TrimEnd('/')+$path;SkipHttpErrorCheck=$true;TimeoutSec=45}
 if($u){$p.Headers=@{Authorization='Bearer '+$u.token}}
 if($null -ne $body){$p.ContentType='application/json; charset=utf-8';$p.Body=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 12))}
 $r=Invoke-WebRequest @p;Check ([int]$r.StatusCode -eq $expected) "$method $path expected $expected got $($r.StatusCode)";if($r.Content){$r.Content|ConvertFrom-Json}
}
function User {
 $key='p3'+[guid]::NewGuid().ToString('N').Substring(0,16)
 $r=Api POST '/auth/register' $null @{email="$key@example.com";nickname=$key;password='TestPass123!'} 201
 @{id=$r.user.id;token=$r.accessToken;email="$key@example.com"}
}
function Login($u){$r=Api POST '/auth/login' $null @{email=$u.email;password='TestPass123!'};$u.token=$r.accessToken}
Check ((Sql 'SELECT MAX(version::int) FROM flyway_schema_history WHERE success') -eq '22') 'Expected V22'
if($VerifyRestart){
 $s=Get-Content -Raw -LiteralPath $StatePath|ConvertFrom-Json -AsHashtable;Login $s.viewer
 $p=Api GET "/posts/$($s.post)" $s.viewer;Check ($p.commentCount -eq 2) 'Comment count persistence'
 $c=Api GET "/posts/$($s.post)/comments" $s.viewer;Check ($c.items[0].commentId -eq $s.root -and $c.items[0].likeCount -eq 1) 'Comment/Like persistence'
 $r=Api GET '/me/reports' $s.viewer;Check (@($r.items.id) -contains $s.report) 'Report persistence'
 Write-Output 'PASS PostgreSQL restart/login: comments, replies, likes, reports and count persisted';return
}
$a=User;$b=User;$c=User;$media=[guid]::NewGuid().ToString()
$null=Sql "INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES('$media','$($a.id)','p3-test','IMAGE','READY','isolated/p3/$media','isolated/p3/${media}_cover','png','image/png',4,2,2)"
$p=Api POST '/posts' $a @{clientRequestId=[guid]::NewGuid().ToString();caption='P3 isolated';audience='EVERYONE';mediaIds=@($media);hashtags=@();taggedUserIds=@()} 201
$id=$p.id;$key=[guid]::NewGuid().ToString();$req=@{clientRequestId=$key;body='Root';parentId=$null;mediaIds=@()}
$root=Api POST "/posts/$id/comments" $b $req 201;$again=Api POST "/posts/$id/comments" $b $req 201
Check ($root.commentId -eq $again.commentId) 'Duplicate comment retry'
$reply=Api POST "/posts/$id/comments" $a @{clientRequestId=[guid]::NewGuid().ToString();body='Reply';parentId=$root.commentId;mediaIds=@()} 201
$nested=Api POST "/posts/$id/comments" $b @{clientRequestId=[guid]::NewGuid().ToString();body='To reply';parentId=$reply.commentId;mediaIds=@()} 201
Check ($nested.parentCommentId -eq $root.commentId -and $nested.replyToUserId -eq $a.id) 'Thread not flattened'
1..2|ForEach-Object {$null=Api PUT "/comments/$($root.commentId)/like" $b}
$detail=Api GET "/posts/$id" $b;Check ($detail.commentCount -eq 3) 'Detail count wrong'
$feed=Api GET '/feed' $b;Check ((@($feed.items|Where-Object id -eq $id)[0]).commentCount -eq 3) 'Feed count wrong'
$profile=Api GET "/users/$($a.id)/posts" $b;Check ((@($profile.items|Where-Object id -eq $id)[0]).commentCount -eq 3) 'Profile count wrong'
$null=Api DELETE "/comments/$($root.commentId)" $a $null 404
$null=Api DELETE "/comments/$($reply.commentId)" $a $null 204
$null=Api PATCH '/users/me/profile' $a @{isPrivate=$true}
$null=Api PUT "/users/$($a.id)/follow" $b
$null=Api GET "/posts/$id/comments" $b $null 404
$r=Api GET '/users/me/follow-requests' $a;$pending=@($r.items|Where-Object requesterId -eq $b.id)[0]
$null=Api POST "/users/me/follow-requests/$($pending.id)/accept" $a
$null=Api GET "/posts/$id/comments" $b
$rkey=[guid]::NewGuid().ToString();$rbody=@{clientRequestId=$rkey;reasonCode='SCAM_OR_SPAM';description='P3 verification'}
$report=Api POST "/posts/$id/reports" $b $rbody 201;$retry=Api POST "/posts/$id/reports" $b $rbody 201
Check ($report.id -eq $retry.id -and $report.status -eq 'PENDING') 'Report retry/status wrong'
$null=Api GET "/me/reports/$($report.id)" $c $null 404
$null=Api POST "/posts/$id/reports" $a @{clientRequestId=[guid]::NewGuid().ToString();reasonCode='SCAM_OR_SPAM'} 403
$null=Api PATCH "/posts/$id/audience" $a @{audience='ONLY_ME'}
$null=Api GET "/posts/$id/comments" $b $null 404
$null=Api GET "/posts/$id/media/$media/thumbnail" $b $null 404
$null=Api PATCH "/posts/$id/audience" $a @{audience='FOLLOWERS'}
@{viewer=$b;post=$id;root=$root.commentId;report=$report.id}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding utf8
Write-Output 'PASS PostgreSQL HTTP: real root/reply/thread, retry, likes, counter Feed/Detail/Profile, ownership, private PENDING/accepted, report history/retry/ownership, protected denial'
