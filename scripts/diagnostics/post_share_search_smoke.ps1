param(
    [ValidateSet('gomate_p4_clean','gomate_p4_upgrade')][string]$Database,
    [ValidateSet(18097,18098)][int]$Port,
    [switch]$Restart
)
$ErrorActionPreference='Stop'
if (($Database -eq 'gomate_p4_clean' -and $Port -ne 18097) -or ($Database -eq 'gomate_p4_upgrade' -and $Port -ne 18098)) { throw 'Scratch database/port mismatch' }
$base="http://127.0.0.1:$Port/api/v1"
function Assert($Condition,[string]$Message) {if (-not $Condition) {throw $Message}}
function Api([string]$Method,[string]$Path,[string]$Token,$Body=$null,[int]$Expected=200) {
    $p=@{Method=$Method;Uri="$base$Path";SkipHttpErrorCheck=$true;ContentType='application/json; charset=utf-8'}
    if($Token){$p.Headers=@{Authorization="Bearer $Token"}}
    if($null -ne $Body){$p.Body=[Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 12 -Compress))}
    $response=Invoke-WebRequest @p
    Assert ($response.StatusCode -eq $Expected) "$Method $Path expected $Expected, got $($response.StatusCode)"
    if($response.Content){return $response.Content | ConvertFrom-Json}
}
function Sql([string]$Sql){
    $out=docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U gomate -d $Database -qAt -c $Sql
    if($LASTEXITCODE){throw 'Scratch SQL failed'}
    return $out
}
function Login([string]$Email){return Api POST '/auth/login' '' @{email=$Email;password='TestPass123!'}}
$statePath="backups/post-share-search/$Database-state.json"
if($Restart) {
    $state=Get-Content $statePath -Raw | ConvertFrom-Json
    $a=Login $state.emailA
    $b=Login $state.emailB
    $history=@(Api GET '/search/recent' $a.accessToken)
    Assert ($history[0] -eq 'Da Nang') 'Recent history did not survive restart'
    $sent=@(Api POST "/posts/$($state.postId)/shares" $a.accessToken $state.share)
    # The final initial-test state is ONLY_ME: recipient must now be denied, not resent.
    Assert (-not $sent[0].success) 'Retry bypassed changed audience'
    $rows=@(Api GET "/conversations/$($state.chatId)/messages" $b.accessToken)
    Assert ($rows.Count -eq 1 -and $rows[0].messageId -eq $state.messageId) 'Durable reference changed after restart'
    Write-Output "$Database RESTART PASS: relogin, persistent recent history, durable single reference, current permissions"
    exit
}
$suffix=[Guid]::NewGuid().ToString('N').Substring(0,12)
$a=Api POST '/auth/register' '' @{email="p4a$suffix@example.com";password='TestPass123!';nickname="p4a$suffix"} 201
$b=Api POST '/auth/register' '' @{email="p4b$suffix@example.com";password='TestPass123!';nickname="p4b$suffix"} 201
$c=Api POST '/auth/register' '' @{email="p4c$suffix@example.com";password='TestPass123!';nickname="p4c$suffix"} 201
$aid=$a.user.id;$bid=$b.user.id;$cid=$c.user.id
$null=Api PUT "/users/$bid/follow" $a.accessToken
$null=Api PUT "/users/$aid/follow" $b.accessToken
$media=[Guid]::NewGuid().ToString()
$null=Sql "INSERT INTO post_media(id,owner_id,content_hash,kind,state,public_id,thumbnail_public_id,format,mime_type,bytes,width,height) VALUES('$media','$aid','p4-test','IMAGE','READY','scratch-$suffix','scratch-$suffix-cover','png','image/png',4,2,2)"
$tag="p4$suffix"
$post=Api POST '/posts' $a.accessToken @{clientRequestId=[Guid]::NewGuid().ToString();caption="Hồ Đà Nẵng $tag";audience='EVERYONE';mediaIds=@($media);hashtags=@($tag,'dulich');taggedUserIds=@()} 201
$pidValue=$post.id
$search=Api GET "/search/posts?q=Da%20Nang%20$tag" $b.accessToken
Assert ($search.items.Count -eq 1 -and $search.items[0].id -eq $pidValue) 'Accent-free Post search failed'
Assert ($search.items[0].thumbnailUrl.StartsWith('/posts/')) 'Thumbnail is not protected'
$and=Api GET "/search/posts?hashtags=$tag,dulich" $b.accessToken
Assert ($and.items.Count -eq 1) 'AND hashtag failed'
for($i=0;$i -lt 10;$i++){$null=Api POST '/search/recent' $a.accessToken @{query="Query $i"}}
$null=Api POST '/search/recent' $a.accessToken @{query='Đà Nẵng'}
$history=@(Api POST '/search/recent' $a.accessToken @{query='Da Nang'})
Assert ($history.Count -eq 8 -and $history[0] -eq 'Da Nang') 'History limit/dedup/order failed'
Assert (@(Api GET '/search/recent' $b.accessToken).Count -eq 0) 'History leaked between accounts'
$targets=@(Api GET "/posts/$pidValue/share-targets" $a.accessToken)
Assert ($bid -in $targets.targetId -and $cid -notin $targets.targetId) 'Invalid eligible targets'
$share=@{clientRequestId=[Guid]::NewGuid().ToString();targets=@(@{type='USER';targetId=$bid},@{type='USER';targetId=$cid});message='Optional message'}
$sent=@(Api POST "/posts/$pidValue/shares" $a.accessToken $share)
Assert ($sent[0].success -and -not $sent[1].success) 'Partial delivery failed'
$retry=@(Api POST "/posts/$pidValue/shares" $a.accessToken $share)
Assert ($retry[0].messageId -eq $sent[0].messageId) 'Retry duplicated message'
$chat=@(Api GET '/conversations' $b.accessToken | Where-Object {$_.peer.userId -eq $aid})[0]
$rows=@(Api GET "/conversations/$($chat.conversationId)/messages" $b.accessToken)
Assert ($rows.Count -eq 1 -and $rows[0].type -eq 'POST_SHARE') 'Mongo reference missing or duplicated'
Assert ($rows[0].context.postId -eq $pidValue -and @($rows[0].context.PSObject.Properties).Count -eq 1) 'Persisted preview leaked fields'
Assert (($rows | ConvertTo-Json -Depth 8) -notmatch 'cloudinary|thumbnail|caption|requestHash') 'Private metadata in message'
# Reuse invitation lifecycle to create one real group; group members may lack Post access.
$trip=Api POST '/trips' $a.accessToken @{title="P4 scratch $suffix";selectedMemberIds=@($bid);startDate='2027-01-01';endDate='2027-01-01'} 201
$invite=@(Api GET '/trip-invitations/incoming?status=PENDING' $b.accessToken | Where-Object {$_.tripId -eq $trip.id})[0]
$group=Api POST "/trip-invitations/$($invite.invitationId)/accept" $b.accessToken
$null=Api PATCH "/posts/$pidValue/audience" $a.accessToken @{audience='ONLY_ME'}
$groupSent=@(Api POST "/posts/$pidValue/shares" $a.accessToken @{clientRequestId=[Guid]::NewGuid().ToString();targets=@(@{type='GROUP';targetId=$group.linkedConversationId})})
Assert ($groupSent[0].success) 'Approved reference-only group share failed'
$null=Api GET "/posts/$pidValue" $b.accessToken $null 404
$null=Api GET "/posts/$pidValue/media/$media/thumbnail" $b.accessToken $null 404
$hidden=Api GET "/search/posts?q=$tag" $b.accessToken
Assert ($hidden.items.Count -eq 0) 'ONLY_ME leaked in Search'
$hiddenTags=@(Api GET "/search/hashtags?q=$tag" $b.accessToken)
Assert ($hiddenTags.Count -eq 0) 'Hidden hashtag count leaked'
$places1=Api GET '/search/places?q=H%E1%BB%93' $a.accessToken
$places2=Api GET '/search/places?q=Ho' $a.accessToken
Assert (($places1.items.placeId -join ',') -eq ($places2.items.placeId -join ',')) 'Place accent normalization differs'
$null=Api GET '/search/places?filters=nearby' $a.accessToken $null 400
$null=Api GET '/search/places?filters=nearby&latitude=11.94&longitude=108.44' $a.accessToken
@{emailA=$a.user.email;emailB=$b.user.email;postId=$pidValue;chatId=$chat.conversationId;messageId=$sent[0].messageId;share=$share} | ConvertTo-Json -Depth 10 | Set-Content $statePath
Write-Output "$Database PASS: register, Post/Place/Search/AND tags, recent history, private counts, DM/group references, partial delivery, retry, protected deny"
