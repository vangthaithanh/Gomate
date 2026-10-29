param(
 [ValidateSet('gomate_dm_clean','gomate_dm_upgrade')][string]$Database,
 [ValidateSet(18099,18100)][int]$Port,
 [switch]$Restart
)
$ErrorActionPreference='Stop'
if (($Database -eq 'gomate_dm_clean' -and $Port -ne 18099) -or ($Database -eq 'gomate_dm_upgrade' -and $Port -ne 18100)) {throw 'Scratch database/port mismatch'}
$base="http://127.0.0.1:$Port/api/v1"
function Assert($Value,[string]$Message) {if (-not $Value) {throw $Message}}
function Api([string]$Method,[string]$Path,[string]$Token,$Body=$null,[int]$Expected=200) {
 $p=@{Method=$Method;Uri="$base$Path";SkipHttpErrorCheck=$true;ContentType='application/json; charset=utf-8'}
 if($Token){$p.Headers=@{Authorization="Bearer $Token"}}
 if($null -ne $Body){$p.Body=[Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 12 -Compress))}
 $response=Invoke-WebRequest @p
 Assert ($response.StatusCode -eq $Expected) "$Method $Path expected $Expected, got $($response.StatusCode)"
 if($response.Content){return $response.Content | ConvertFrom-Json}
}
function Sql([string]$Query) {
 $value=docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U gomate -d $Database -qAt -c $Query
 if($LASTEXITCODE){throw 'Scratch SQL failed'}
 return $value
}
function First($Sender,$Recipient,[string]$Text) {
 return Api POST '/conversations/direct/messages' $Sender.accessToken @{targetUserId=$Recipient.user.id;clientRequestId=[Guid]::NewGuid().ToString();text=$Text} 201
}
$statePath="backups/dm-privacy/$Database-state.json"
if($Restart) {
 $state=Get-Content $statePath -Raw | ConvertFrom-Json
 $a=Api POST '/auth/login' '' @{email=$state.email;password='TestPass123!'}
 $retry=Api POST '/conversations/direct/messages' $a.accessToken $state.request 201
 Assert ($retry.conversation.conversationId -eq $state.chat -and $retry.message.messageId -eq $state.message) 'First-send retry changed after restart'
 $rows=@(Api GET "/conversations/$($state.chat)/messages" $a.accessToken)
 Assert ($rows.Count -eq 1) 'Restart/relogin duplicated message'
 Write-Output "$Database RESTART PASS: persisted pair/body and idempotent first-send"
 exit
}
$suffix=[Guid]::NewGuid().ToString('N').Substring(0,10)
$a=Api POST '/auth/register' '' @{email="dma$suffix@example.com";password='TestPass123!';nickname="dma$suffix"} 201
$b=Api POST '/auth/register' '' @{email="dmb$suffix@example.com";password='TestPass123!';nickname="dmb$suffix"} 201
$c=Api POST '/auth/register' '' @{email="dmc$suffix@example.com";password='TestPass123!';nickname="dmc$suffix"} 201
$d=Api POST '/auth/register' '' @{email="dmd$suffix@example.com";password='TestPass123!';nickname="dmd$suffix"} 201
$aid=$a.user.id;$bid=$b.user.id;$cid=$c.user.id;$did=$d.user.id
$count=[long](Sql 'SELECT COUNT(*) FROM conversations')
$null=Api PATCH '/users/me' $b.accessToken @{isPrivate=$true}
$profile=Api GET "/users/$bid" $a.accessToken
Assert (-not $profile.canInitiateMessage) 'Private stranger can initiate'
$null=Api POST '/conversations/direct' $a.accessToken @{targetUserId=$bid} 403
$null=Api POST '/conversations/direct/messages' $a.accessToken @{targetUserId=$bid;clientRequestId=[Guid]::NewGuid().ToString();text='Bypass'} 403
$draft=Api POST '/conversations/direct' $b.accessToken @{targetUserId=$aid} 201
Assert ($draft.status -eq 'DRAFT' -and $null -eq $draft.conversationId) 'Open should be draft'
Assert ([long](Sql 'SELECT COUNT(*) FROM conversations') -eq $count) 'Open persisted empty chat'
$pending=First $b $a 'Private sender to public receiver'
$chat=$pending.conversation.conversationId
Assert ($pending.conversation.status -eq 'PENDING') 'Non-mutual first send should be pending'
Assert (@(Api GET '/conversations' $a.accessToken | Where-Object {$_.conversationId -eq $chat}).Count -eq 0) 'Pending leaked into Main'
Assert (@(Api GET '/message-requests' $a.accessToken | Where-Object {$_.conversationId -eq $chat}).Count -eq 1) 'Recipient queue missing'
$null=Api POST "/message-requests/$chat/accept" $b.accessToken $null 403
$null=Api POST "/message-requests/$chat/accept" $c.accessToken $null 404
$detail=Api GET "/conversations/$chat" $a.accessToken
Assert ($detail.conversation.status -eq 'PENDING') 'Opening request autoaccepted'
$null=Api POST "/message-requests/$chat/accept" $a.accessToken
$null=Api POST "/message-requests/$chat/accept" $a.accessToken
$null=Api POST "/conversations/$chat/messages" $a.accessToken @{text='Accepted continuation';clientRequestId=[Guid]::NewGuid().ToString()} 201
Assert (-not (Api GET "/users/$bid" $a.accessToken).canInitiateMessage) 'Accepted incorrectly overrides Profile privacy'
$null=Api PUT "/users/$bid/follow" $a.accessToken
Assert (-not (Api GET "/users/$bid" $a.accessToken).canInitiateMessage) 'Pending follow became permission'
$follow=@((Api GET '/users/me/follow-requests' $b.accessToken).items | Where-Object {$_.requesterId -eq $aid})[0]
$null=Api POST "/users/me/follow-requests/$($follow.id)/accept" $b.accessToken
Assert ((Api GET "/users/$bid" $a.accessToken).canInitiateMessage) 'Accepted one-way follow missing permission'

$request=@{targetUserId=$did;clientRequestId=[Guid]::NewGuid().ToString();text='Persistent first send'}
$first=Api POST '/conversations/direct/messages' $c.accessToken $request 201
$retry=Api POST '/conversations/direct/messages' $c.accessToken $request 201
Assert ($first.message.messageId -eq $retry.message.messageId) 'Retry duplicated first message'
$cd=$first.conversation.conversationId
$null=Api PUT "/users/$did/follow" $c.accessToken
$null=Api PUT "/users/$cid/follow" $d.accessToken
Assert ((Api GET "/conversations/$cd" $d.accessToken).conversation.status -eq 'PENDING') 'Mutual automatically accepted pending'
$media=[Guid]::NewGuid().ToString()
$null=Sql "INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES('$media','$cid','dm-scratch','IMAGE','READY','scratch-$suffix','scratch-$suffix-cover','png','image/png',4,2,2)"
$post=Api POST '/posts' $c.accessToken @{clientRequestId=[Guid]::NewGuid().ToString();caption="DM test $suffix";audience='EVERYONE';mediaIds=@($media);hashtags=@();taggedUserIds=@()} 201
$share=@{clientRequestId=[Guid]::NewGuid().ToString();targets=@(@{type='USER';targetId=$did})}
$sent=@(Api POST "/posts/$($post.id)/shares" $c.accessToken $share)
Assert (-not $sent[0].success) 'Share accepted pending'
$null=Api POST "/message-requests/$cd/accept" $d.accessToken
$null=Api DELETE "/users/$did/follow" $c.accessToken
$null=Api DELETE "/users/$cid/follow" $d.accessToken
$null=Api PATCH '/users/me' $d.accessToken @{isPrivate=$true}
$sent=@(Api POST "/posts/$($post.id)/shares" $c.accessToken $share)
$resent=@(Api POST "/posts/$($post.id)/shares" $c.accessToken $share)
Assert ($sent[0].success -and $sent[0].messageId -eq $resent[0].messageId) 'Accepted after unfollow Share failed or duplicated'
Assert (@(Api GET "/posts/$($post.id)/share-targets" $c.accessToken | Where-Object {$_.targetId -eq $did}).Count -eq 1) 'Accepted unfollowed target missing'
$null=Api PUT "/users/$aid/follow" $c.accessToken
$null=Api PUT "/users/$cid/follow" $a.accessToken
$newShare=@{clientRequestId=[Guid]::NewGuid().ToString();targets=@(@{type='USER';targetId=$aid})}
$newSent=@(Api POST "/posts/$($post.id)/shares" $c.accessToken $newShare)
Assert ($newSent[0].success) 'Mutual first Share failed to create accepted DM'
Assert ([long](Sql "SELECT COUNT(*) FROM conversations WHERE type='DIRECT' AND ((user_low_id='$cid' AND user_high_id='$aid') OR (user_low_id='$aid' AND user_high_id='$cid')) AND status='ACCEPTED'") -eq 1) 'First Share duplicated pair'

# A separate request is kept unchanged for restart/relogin verification.
$persist=@{targetUserId=$bid;clientRequestId=[Guid]::NewGuid().ToString();text='Restart proof'}
$null=Api PATCH '/users/me' $b.accessToken @{isPrivate=$false}
$saved=Api POST '/conversations/direct/messages' $d.accessToken $persist 201
@{email=$d.user.email;request=$persist;chat=$saved.conversation.conversationId;message=$saved.message.messageId} | ConvertTo-Json -Depth 8 | Set-Content $statePath
Assert ((Sql 'SELECT MAX(version::int) FROM flyway_schema_history WHERE success') -eq '24') 'Flyway version changed'
Write-Output "$Database PASS: privacy/draft, recipient-only requests, no autoaccept, first-send retry, accepted continuation, P4 accepted/unfollow + mutual first Share, Flyway V24"
