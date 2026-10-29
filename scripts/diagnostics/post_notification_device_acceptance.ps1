param(
 [Parameter(Mandatory)][ValidateSet('Inspect','Like','Unlike','Comment','Reply','DeleteComment')][string]$Action,
 [Parameter(Mandatory)][long]$PostId,
 [Parameter(Mandatory)][guid]$RecipientId,
 [long]$ParentCommentId,
 [long]$CommentId,
 [string]$Fixture='backups/realtime_device_fixture_20261015_171910.json',
 [string]$State='backups/post-likers-device-acceptance/manual-state.json',
 [switch]$RetryLast
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../backups'))+[IO.Path]::DirectorySeparatorChar
foreach($path in @($Fixture,$State)) {
 if(-not [IO.Path]::GetFullPath($path).StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) {throw 'Local fixture/state must stay in ignored backups'}
}
$f=Get-Content -Raw -LiteralPath $Fixture|ConvertFrom-Json
$sender=[guid]$f.senderUserId
function Sql($q) {
 $r=docker compose exec -T postgres psql -U gomate -d gomate_auth -qAt -v ON_ERROR_STOP=1 -c $q
 if($LASTEXITCODE -ne 0) {throw 'Diagnostic SQL failed'}
 ($r -join "`n").Trim()
}
if((Sql "SELECT full_name FROM user_profiles WHERE user_id='$sender'") -ne 'GoMate Test Realtime') {throw 'Only the existing dedicated test account is allowed'}
function Api($method,$path,$token,$body=$null) {
 $p=@{Method=$method;Uri='http://127.0.0.1:8081/api/v1'+$path;TimeoutSec=30;SkipHttpErrorCheck=$true}
 if($token) {$p.Headers=@{Authorization='Bearer '+$token}}
 if($null -ne $body) {$p.ContentType='application/json; charset=utf-8';$p.Body=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 10))}
 $r=Invoke-WebRequest @p
 if([int]$r.StatusCode -ge 400) {throw "$method $path returned HTTP $([int]$r.StatusCode)"}
 if($r.Content) {$r.Content|ConvertFrom-Json}
}
# Credentials come from the pre-existing controlled fixture, never a real user's session.
$session=Api POST '/auth/login' $null @{email=$f.email;password=$f.password}
if([guid]$session.user.id -ne $sender) {throw 'Unexpected login actor'}
$token=$session.accessToken
$post=Api GET "/posts/$PostId" $token
if($Action -in @('Like','Unlike','Comment') -and [guid]$post.authorId -ne $RecipientId) {throw 'Post owner is not the intended notification recipient'}
if($Action -eq 'Inspect') {
 $liked=Sql "SELECT COUNT(*) FROM post_likes WHERE post_id=$PostId AND user_id='$sender'"
 Write-Output "Ready: controlled actor authorized for Post $PostId; existing Like=$liked; no interaction sent"
 return
}
$stateData=if(Test-Path -LiteralPath $State) {Get-Content -Raw -LiteralPath $State|ConvertFrom-Json -AsHashtable} else {@{events=@()}}
$type='POST_LIKE';$comment=$null;$request=$null
switch($Action) {
 'Like' {$null=Api PUT "/posts/$PostId/like" $token}
 'Unlike' {$null=Api DELETE "/posts/$PostId/like" $token}
 {$_ -in @('Comment','Reply')} {
  if($Action -eq 'Reply') {
   if($ParentCommentId -lt 1 -or (Sql "SELECT user_id FROM comments WHERE id=$ParentCommentId AND post_id=$PostId") -ne $RecipientId.ToString()) {throw 'Reply target must be the intended recipient on this Post'}
  }
  $request=@{clientRequestId=[guid]::NewGuid().ToString();body="[TEST GoMate] $Action $(Get-Date -Format HH:mm:ss)";parentId=if($Action -eq 'Reply'){$ParentCommentId}else{$null};mediaIds=@()}
  if($RetryLast) {
   if($stateData.lastAction -ne $Action -or $stateData.lastPost -ne $PostId -or $null -eq $stateData.lastRequest) {throw 'No matching previous request for retry'}
   $request=$stateData.lastRequest
  }
  $response=Api POST "/posts/$PostId/comments" $token $request
  $comment=[long]$response.commentId
  $type=if($Action -eq 'Reply'){'POST_REPLY'}else{'POST_COMMENT'}
  $stateData.lastAction=$Action;$stateData.lastPost=$PostId;$stateData.lastRequest=$request
 }
 'DeleteComment' {
  if($CommentId -lt 1 -or (Sql "SELECT user_id FROM comments WHERE id=$CommentId AND post_id=$PostId") -ne $sender.ToString()) {throw 'Only a comment owned by the test actor may be removed'}
  $null=Api DELETE "/comments/$CommentId" $token
  Write-Output "Deleted controlled test Comment $CommentId through its own API; original notification retained"
  return
 }
}
$filter=if($null -eq $comment) {"entity_type='POST_LIKE' AND entity_id='${PostId}:$sender'"} else {"entity_type='POST_COMMENT' AND entity_id='$comment'"}
$notice=Sql "SELECT id FROM notifications WHERE user_id='$RecipientId' AND actor_id='$sender' AND type='$type' AND $filter"
$count=Sql "SELECT COUNT(*) FROM notifications WHERE user_id='$RecipientId' AND actor_id='$sender' AND type='$type' AND $filter"
$event=@{time=(Get-Date).ToString('o');action=$Action;postId=$PostId;commentId=$comment;notificationId=$notice;recipientId=$RecipientId.ToString();records=[int]$count;retry=$RetryLast.IsPresent}
$stateData.events=@($stateData.events)+@($event)
$stateData|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $State -Encoding utf8
$event|ConvertTo-Json -Compress
