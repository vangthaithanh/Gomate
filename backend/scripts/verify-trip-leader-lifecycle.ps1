param(
    [string]$BaseUrl = 'http://127.0.0.1:18084/api/v1',
    [Parameter(Mandatory)][string]$Database,
    [Parameter(Mandatory)][string]$MongoDatabase
)
$ErrorActionPreference = 'Stop'
$uri = [uri]$BaseUrl
if ($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -notin @(18084,18085,18086,18087) -or
    $Database -notmatch '^gomate_(phase44b|pin_reset)_[a-z0-9_]+$' -or $MongoDatabase -notmatch '^gomate_(phase44b|pin_reset)_[a-z0-9_]+$') {
    throw 'Use isolated Phase 4.4B databases/API only. Never target the user database.'
}
function Check($Value,[string]$Message) { if (!$Value) { throw $Message } }
function Sql([string]$Query) {
    $result=docker compose exec -T postgres psql -U gomate -d $Database -qAt -v ON_ERROR_STOP=1 -c $Query
    if ($LASTEXITCODE -ne 0) { throw 'Verification SQL failed' }
    ($result -join "`n").Trim()
}
function MongoCount([string]$Collection) {
    $result=docker compose exec -T mongo mongosh --quiet --eval "db.getSiblingDB('$MongoDatabase').getCollection('$Collection').countDocuments({})"
    if ($LASTEXITCODE -ne 0) { throw 'Verification Mongo count failed' }
    [int](($result -join "`n").Trim())
}
function Api([string]$Method,[string]$Path,$Session,$Body=$null,[int]$Expected=200) {
    $args=@{Method=$Method;Uri=$BaseUrl+$Path;TimeoutSec=25;SkipHttpErrorCheck=$true}
    if ($Session) { $args.Headers=@{Authorization='Bearer '+$Session.accessToken} }
    if ($null -ne $Body) { $args.ContentType='application/json'; $args.Body=ConvertTo-Json $Body -Depth 8 }
    $response=Invoke-WebRequest @args
    Check ([int]$response.StatusCode -eq $Expected) "$Method $Path expected $Expected, got $($response.StatusCode)"
    if ($response.Content) { ConvertFrom-Json $response.Content }
}
function User {
    $suffix=[guid]::NewGuid().ToString('N')
    Api POST '/auth/register' $null @{email="$suffix@example.invalid";password="TestOnly123!$suffix";nickname="ll_$($suffix.Substring(0,12))"} 201
}
function NewTrip($Leader) {
    Api POST '/trips' $Leader @{title='Leader lifecycle verification';startDate='2026-12-01';endDate='2026-12-02'} 201
}
function Invite($Leader,$Target,[string]$Id) { Api POST "/trips/$Id/invitations" $Leader @{inviteeUserId=$Target.user.id} 201 }
function Join($Leader,$Target,[string]$Id) {
    $invitation=Invite $Leader $Target $Id
    Api POST "/trip-invitations/$($invitation.invitationId)/accept" $Target
}

$a=User; $b=User; $c=User
$trip=NewTrip $a; $id=$trip.id
$group=Join $a $b $id; $chat=$group.linkedConversationId
$null=Api DELETE "/trips/$id/members/me" $a $null 422
$after=Api PATCH "/trips/$id/leader" $a @{targetUserId=$b.user.id}
Check ($after.linkedConversationId -eq $chat -and $after.memberCount -eq 2) 'Transfer replaced chat or removed old leader'
Check ((Sql "SELECT role FROM trip_members WHERE trip_id='$id' AND user_id='$($a.user.id)'") -eq 'MEMBER') 'Old leader not demoted'
Check ((Sql "SELECT role FROM trip_members WHERE trip_id='$id' AND user_id='$($b.user.id)'") -eq 'LEADER') 'Target not promoted'
Check ((Sql "SELECT COUNT(*) FROM conversation_members cm JOIN trip_members tm ON tm.user_id=cm.user_id AND tm.trip_id='$id' WHERE cm.conversation_id='$chat' AND cm.role<>tm.role") -eq '0') 'Trip/chat role mismatch'
$null=Api DELETE "/trips/$id/members/me" $a $null 204
$personal=Api GET "/trips/$id" $b
Check ($personal.tripType -eq 'PERSONAL' -and !$personal.linkedConversationId) 'Phase 4.4A last-member transition regressed'
$regroup=Join $b $c $id
Check ($regroup.linkedConversationId -ne $chat) 'Old chat was reused'

# Archive with actual PostgreSQL history and actual Mongo message/location writes.
$newChat=$regroup.linkedConversationId
$null=Api POST "/trips/$id/pin" $c
$null=Api POST "/conversations/$newChat/messages" $b @{text='Phase44B retained history'} 201
$beforeLocations=MongoCount 'trip_current_locations'
$null=Api PUT "/trips/$id/location" $c @{latitude=11.94;longitude=108.44}
Check ((MongoCount 'trip_current_locations') -eq ($beforeLocations+1)) 'Expected a real location snapshot'
$beforeMessages=MongoCount 'messages'
Check ($beforeMessages -ge 1) 'Expected a real Mongo message'
$pendingUser=User
$pending=Invite $b $pendingUser $id
$null=Api POST "/trips/$id/pin" $b
$null=Api POST "/trips/$id/pin" $c
$fixtureCode='ll_'+[guid]::NewGuid().ToString('N').Substring(0,10)
$category=Sql "INSERT INTO place_categories(code,name) VALUES('$fixtureCode','$fixtureCode') RETURNING id"
$place=Sql "INSERT INTO places(category_id,name,province,latitude,longitude) VALUES($category,'Lifecycle test Place','Test',11.94,108.44) RETURNING id"
$stop=Api POST "/trips/$id/stops" $b @{placeId=[long]$place} 201
$null=Sql "INSERT INTO trip_reminders(id,trip_id,recipient_user_id,reminder_type,remind_at) VALUES('$([guid]::NewGuid())','$id','$($b.user.id)','TRIP_START',CURRENT_TIMESTAMP)"
$beforeNotifications=Sql 'SELECT COUNT(*) FROM notifications'
$beforeInvitations=Sql "SELECT COUNT(*) FROM trip_invitations WHERE trip_id='$id'"
$null=Api DELETE "/trips/$id" $c $null 403
$null=Api DELETE "/trips/$id" $b $null 204
$null=Api DELETE "/trips/$id" $b $null 204
Check ((Sql "SELECT COUNT(*) FROM trips WHERE id='$id' AND archived_at IS NOT NULL") -eq '1') 'Trip was hard deleted'
foreach ($table in @('trip_stops','trip_reminders')) { Check ((Sql "SELECT COUNT(*) FROM $table WHERE trip_id='$id'") -eq '1') "$table history lost" }
Check ((Sql "SELECT COUNT(*) FROM trip_members WHERE trip_id='$id'") -eq '2') 'Membership history lost'
Check ((Sql "SELECT COUNT(*) FROM trip_invitations WHERE trip_id='$id'") -eq $beforeInvitations) 'Invitations deleted'
Check ((Sql 'SELECT COUNT(*) FROM notifications') -eq $beforeNotifications) 'Notifications deleted/duplicated'
Check ((Sql "SELECT COUNT(*) FROM trip_invitations WHERE trip_id='$id' AND status='PENDING'") -eq '0') 'Pending invitations not cancelled'
Check ((Sql "SELECT COUNT(*) FROM conversations WHERE linked_trip_id='$id' AND status='ACCEPTED'") -eq '0') 'Chat still active'
Check ((Sql "SELECT COUNT(*) FROM trip_pins WHERE trip_id='$id'") -eq '0') 'Pins not cleared'
Check ((MongoCount 'trip_current_locations') -eq $beforeLocations) 'Current snapshots not cleaned after commit'
Check ((MongoCount 'messages') -eq $beforeMessages) 'Mongo messages deleted'
foreach ($viewer in @($b,$c)) {
    $null=Api GET "/trips/$id" $viewer $null 404
    Check (@(Api GET '/trips' $viewer).Count -eq 0) 'Archived Trip still listed'
    Check (!(Api GET '/trips/pinned' $viewer).trip) 'Archived Trip pinned'
    $null=Api GET "/trips/$id/locations" $viewer $null 404
    $null=Api PUT "/trips/$id/location" $viewer @{latitude=11.94;longitude=108.44} 404
    $null=Api POST "/conversations/$newChat/messages" $viewer @{text='denied'} 404
}
$null=Api POST "/trip-invitations/$($pending.invitationId)/accept" $pendingUser $null 409
$notice=(Api GET '/notifications' $pendingUser).items[0]
Check ($notice.invitationStatus -eq 'CANCELLED' -and !$notice.tripId) 'Stale notice still actionable'
$results=@([ordered]@{case='transfer_archive_real_stores';tripId=$id;oldChat=$chat;newChat=$newChat;result='PASS'})

# Real simultaneous HTTP transactions against PostgreSQL, not H2-only races.
$p=$pendingUser; $d=User
foreach ($race in @('twoTransfers','targetLeave','targetRemove','archiveTransfer','archiveAccept','archiveInvite','archiveLeave','archiveMutation')) {
    $trip=NewTrip $a; $id=$trip.id
    $null=Join $a $b $id; $null=Join $a $c $id
    $pending=Invite $a $p $id
    $archive=$race.StartsWith('archive')
    $first=@{method=if($archive){'DELETE'}else{'PATCH'};path=if($archive){"/trips/$id"}else{"/trips/$id/leader"};session=$a;body=if($archive){$null}else{@{targetUserId=$b.user.id}}}
    $second=switch ($race) {
        'twoTransfers' { @{method='PATCH';path="/trips/$id/leader";session=$a;body=@{targetUserId=$c.user.id}} }
        'targetLeave' { @{method='DELETE';path="/trips/$id/members/me";session=$b} }
        'targetRemove' { @{method='DELETE';path="/trips/$id/members/$($b.user.id)";session=$a} }
        'archiveTransfer' { @{method='PATCH';path="/trips/$id/leader";session=$a;body=@{targetUserId=$b.user.id}} }
        'archiveAccept' { @{method='POST';path="/trip-invitations/$($pending.invitationId)/accept";session=$p} }
        'archiveInvite' { @{method='POST';path="/trips/$id/invitations";session=$a;body=@{inviteeUserId=$d.user.id}} }
        'archiveLeave' { @{method='DELETE';path="/trips/$id/members/me";session=$b} }
        'archiveMutation' { @{method='PATCH';path="/trips/$id";session=$a;body=@{title='Race renamed'}} }
    }
    $client=[System.Net.Http.HttpClient]::new()
    $client.Timeout=[timespan]::FromSeconds(25)
    $requests=@(); $responses=@()
    try {
        foreach ($item in @($first,$second)) {
            $request=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($item.method),$BaseUrl+$item.path)
            $request.Headers.Authorization=[System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$item.session.accessToken)
            if ($item.body) { $request.Content=[System.Net.Http.StringContent]::new((ConvertTo-Json $item.body),[Text.Encoding]::UTF8,'application/json') }
            $requests += $request
        }
        $f1=$client.SendAsync($requests[0]); $f2=$client.SendAsync($requests[1])
        $responses=@($f1.GetAwaiter().GetResult(),$f2.GetAwaiter().GetResult())
        $codes=@($responses | ForEach-Object { [int]$_.StatusCode })
        Check (@($codes | Where-Object { $_ -notin @(200,201,204,403,404,409,422) }).Count -eq 0) "Uncontrolled race $race statuses=$codes"
        Check ((Sql "SELECT COUNT(*) FROM trip_members WHERE trip_id='$id' AND role='LEADER' AND status='ACTIVE'") -eq '1') "Invalid leader count $race"
        $isArchived=(Sql "SELECT COUNT(*) FROM trips WHERE id='$id' AND archived_at IS NOT NULL") -eq '1'
        $expectedChats=if($isArchived){'0'}else{'1'}
        Check ((Sql "SELECT COUNT(*) FROM conversations WHERE linked_trip_id='$id' AND status='ACCEPTED'") -eq $expectedChats) "Invalid active chat count $race"
        if ($isArchived) { Check ((Sql "SELECT COUNT(*) FROM trip_invitations WHERE trip_id='$id' AND status='PENDING'") -eq '0') 'Archive race left pending invite' }
        Check ((Sql "SELECT COUNT(*) FROM conversation_members cm JOIN conversations c ON c.id=cm.conversation_id JOIN trip_members tm ON tm.trip_id=c.linked_trip_id AND tm.user_id=cm.user_id WHERE c.linked_trip_id='$id' AND c.status='ACCEPTED' AND cm.role<>tm.role") -eq '0') 'Role mismatch after race'
        $results += [ordered]@{case=$race;httpStatuses=$codes;archived=$isArchived;result='PASS'}
    } finally {
        foreach ($response in $responses) { $response.Dispose() }
        foreach ($request in $requests) { $request.Dispose() }
        $client.Dispose()
    }
}
ConvertTo-Json -InputObject $results -Depth 5
