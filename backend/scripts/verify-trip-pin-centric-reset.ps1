param(
    [string]$BaseUrl = 'http://127.0.0.1:18086/api/v1',
    [Parameter(Mandatory)][string]$Database,
    [Parameter(Mandatory)][string]$MongoDatabase
)
$ErrorActionPreference = 'Stop'
$uri = [uri]$BaseUrl
if ($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -notin @(18086,18087) -or
    $Database -notmatch '^gomate_pin_reset_[a-z0-9_]+$' -or
    $MongoDatabase -notmatch '^gomate_pin_reset_[a-z0-9_]+$') {
    throw 'Use isolated pin-reset databases/API only; never user data.'
}
function Check($Value,[string]$Message) { if (!$Value) { throw $Message } }
function Sql([string]$Query) {
    $r=docker compose exec -T postgres psql -U gomate -d $Database -qAt -v ON_ERROR_STOP=1 -c $Query
    if ($LASTEXITCODE -ne 0) { throw 'SQL failed' }; ($r -join "`n").Trim()
}
function Mongo([string]$Code) {
    $r=docker compose exec -T mongo mongosh --quiet --eval "db.getSiblingDB('$MongoDatabase').$Code"
    if ($LASTEXITCODE -ne 0) { throw 'Mongo query failed' }; ($r -join "`n").Trim()
}
function Api([string]$Method,[string]$Path,$User,$Body=$null,[int]$Expected=200) {
    $args=@{Method=$Method;Uri=$BaseUrl+$Path;TimeoutSec=25;SkipHttpErrorCheck=$true}
    if ($User) { $args.Headers=@{Authorization='Bearer '+$User.accessToken} }
    if ($null -ne $Body) { $args.ContentType='application/json'; $args.Body=ConvertTo-Json $Body -Depth 8 }
    $r=Invoke-WebRequest @args
    Check ([int]$r.StatusCode -eq $Expected) "$Method $Path expected $Expected, got $($r.StatusCode): $($r.Content)"
    if ($r.Content) { ConvertFrom-Json $r.Content }
}
function User {
    $s=[guid]::NewGuid().ToString('N')
    Api POST '/auth/register' $null @{email="$s@example.invalid";password="TestOnly123!$s";nickname="loc_$($s.Substring(0,12))"} 201
}
function OpenStream($User,[string]$TripId,[int]$Expected=200) {
    $client=[System.Net.Http.HttpClient]::new()
    $client.Timeout=[TimeSpan]::FromSeconds(90)
    $request=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get,"$BaseUrl/trips/$TripId/locations/stream")
    $request.Headers.Authorization=[System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$User.accessToken)
    $response=$client.SendAsync($request,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    Check ([int]$response.StatusCode -eq $Expected) "SSE expected $Expected got $($response.StatusCode)"
    if ($Expected -ne 200) { $response.Dispose();$request.Dispose();$client.Dispose();return }
    $reader=[System.IO.StreamReader]::new($response.Content.ReadAsStream())
    @{Client=$client;Request=$request;Response=$response;Reader=$reader}
}
function ReadEvent($Stream,[string]$Kind) {
    $until=[DateTime]::UtcNow.AddSeconds(8)
    while ([DateTime]::UtcNow -lt $until) {
        $lineTask=$Stream.Reader.ReadLineAsync()
        Check ($lineTask.Wait(8000)) 'Timed out waiting for SSE'
        $line=$lineTask.Result
        if ($null -eq $line) { throw 'SSE unexpectedly closed' }
        if ($line -eq "event:$Kind") { return }
    }
    throw "SSE missing $Kind"
}
function CloseStream($s) { if($s){$s.Reader.Dispose();$s.Response.Dispose();$s.Request.Dispose();$s.Client.Dispose()} }


$a=User; $b=User; $outside=User
$null=Api POST '/auth/login' $null @{email=$a.user.email;password='intentionally-wrong'} 401
$today=(Api GET '/trips/time-context' $a).today
$trip=Api POST '/trips' $a @{title='Pin-centric verification';startDate=$today;endDate=$today;selectedMemberIds=@($b.user.id)} 201
$id=$trip.id
# Historical fixture only in the explicitly isolated verification database.
$null=Sql "UPDATE trips SET start_date='2020-01-01',end_date='2020-01-02' WHERE id='$id'"
Check ($trip.tripType -eq 'PERSONAL' -and !$trip.pinned) 'Create must not pin or activate membership'
Check (!$trip.PSObject.Properties['status']) 'Trip status must not be in API'
$invite=$trip.pendingInvitations[0].invitationId
$group=Api POST "/trip-invitations/$invite/accept" $b
$chat=$group.linkedConversationId
Check ($group.tripType -eq 'GROUP' -and $group.members.Count -eq 2 -and $chat) 'Accept did not create active GROUP chat'
Check ($null -eq (Api GET '/trips/pinned' $a).trip -and $null -eq (Api GET '/trips/pinned' $b).trip) 'Accept auto-pinned a user'
$other=Api POST '/trips' $b @{title='Independent pin C';startDate='2026-12-01';endDate='2026-12-02'} 201
$null=Api POST "/trips/$($other.id)/pin" $b
$null=Api PUT "/trips/$($other.id)/location" $b @{latitude=11.94;longitude=108.44}
$null=Api GET "/trips/$id" $b
Check ((Api GET '/trips/pinned' $b).trip.id -eq $other.id) 'View replaced pin C'
$null=Api PUT "/trips/$id/location" $b @{latitude=11.94;longitude=108.44} 403
$null=Api POST "/trips/$id/pin" $b
Check (@(Api GET "/trips/$($other.id)/locations" $b).Count -eq 1) 'Pin switch lost last-known position'
$null=Api POST "/trips/$id/pin" $a
$null=Api POST "/trips/$id/pin" $a
Check ((Sql "SELECT COUNT(*) FROM trip_pins WHERE user_id='$($a.user.id)'") -eq '1') 'Duplicate pin'
$null=Api PUT "/trips/$id/location" $a @{latitude=11.95;longitude=108.45}
$before=[int](Mongo 'trip_current_locations.countDocuments({})')
$inbox=Sql 'SELECT COUNT(*) FROM notifications'
$sa=$null
try {
    $null=OpenStream $outside $id 404
    $sa=OpenStream $a $id
    ReadEvent $sa 'ready'
    $first=Api PUT "/trips/$id/location" $b @{latitude=11.94;longitude=108.44;runtimeMode='BACKGROUND';capturedAt='2020-01-01T00:00:00Z'}
    ReadEvent $sa 'tripLocationUpdated'
    Start-Sleep -Milliseconds 30
    $second=Api PUT "/trips/$id/location" $b @{latitude=11.94;longitude=108.44;runtimeMode='FOREGROUND'}
    ReadEvent $sa 'tripLocationUpdated'
    Check ([DateTimeOffset]$second.updatedAt -gt [DateTimeOffset]$first.updatedAt) 'Stationary server ACK did not advance'
    Check ([int](Mongo 'trip_current_locations.countDocuments({})') -eq $before+1) 'Snapshot not UPSERT'
    $null=Api PUT "/trips/$id/location" $b @{latitude=100;longitude=108.44} 400
    $null=Api PUT "/trips/$id/location" $b @{latitude=11.94;longitude=108.44;userId=$a.user.id} 400
    $null=Api DELETE "/trips/$id/pin" $b $null 204
    $retained=@(Api GET "/trips/$id/locations" $a)
    Check ($retained.Count -eq 2) 'Unpin lost last-known member position'
    $last=@($retained | Where-Object userId -eq $b.user.id)[0]
    Check ($last.updatedAt -eq $second.updatedAt -and $last.latitude -eq $second.latitude -and $last.longitude -eq $second.longitude) 'Unpin changed last-known timestamp/coordinate'
    Check ([int](Mongo 'trip_current_locations.countDocuments({})') -eq $before+1) 'Unpin deleted or duplicated snapshot'
    Check ((Api GET '/trips/pinned' $a).trip.id -eq $id) 'Unpin touched other user pin'
    foreach($mode in @('FOREGROUND','BACKGROUND')) {
        $null=Api PUT "/trips/$id/location" $b @{latitude=11.94;longitude=108.44;runtimeMode=$mode} 403
    }
    Check ((Sql 'SELECT COUNT(*) FROM notifications') -eq $inbox) 'Location wrote inbox notification'
    $detail=Api GET "/trips/$id" $a
    Check ($detail.linkedConversationId -eq $chat -and $detail.members.Count -eq 2) 'Unpin changed chat/membership'
    foreach($suffix in @('start','complete','cancel')) { $null=Api POST "/trips/$id/$suffix" $a $null 404 }
    $null=Api GET "/trips/$id/location-sharing" $a $null 404
    $null=Api PATCH "/trips/$id" $a @{status='ACTIVE'} 400
    $null=Api PATCH "/trips/$id" $a @{title='Still editable'}
    $null=Api POST "/trips/$($other.id)/pin" $b
    $null=Api PATCH "/trips/$id/leader" $a @{targetUserId=$b.user.id}
    Check ((Api GET '/trips/pinned' $b).trip.id -eq $other.id) 'Leader transfer changed target pin'
    $null=Api DELETE "/trips/$id/members/me" $a $null 204
    ReadEvent $sa 'tripUnavailable'
    $null=Api PUT "/trips/$id/location" $a @{latitude=11.94;longitude=108.44} 404
    Check ((Api GET '/trips/pinned' $b).trip.id -eq $other.id) 'Member leave touched unrelated pin'
    $null=Api GET "/conversations/$chat" $a $null 404
    $pending=Api POST "/trips/$id/invitations" $b @{inviteeUserId=$outside.user.id} 201
    $null=Api DELETE "/trips/$id" $b $null 204
    $null=Api DELETE "/trips/$id" $b $null 204
    $null=Api GET "/trips/$id" $b $null 404
    Check ((Sql "SELECT COUNT(*) FROM trips WHERE id='$id' AND archived_at IS NOT NULL") -eq '1') 'Delete did not preserve soft archive'
    Check ((Sql "SELECT status FROM conversations WHERE id='$chat'") -eq 'CLOSED') 'Delete/last-member did not close chat'
    Check ((Sql "SELECT status FROM trip_invitations WHERE id='$($pending.invitationId)'") -eq 'CANCELLED') 'Delete did not cancel pending invite'
} finally { CloseStream $sa }
# Isolated PostgreSQL stop/time/reorder + Auth/Place/Route regressions.
$category=Sql "INSERT INTO place_categories(code,name,active) VALUES('pin_reset_fixture','Pin reset fixture',TRUE) ON CONFLICT(code) DO UPDATE SET name=EXCLUDED.name RETURNING id"
$placeA=Sql "INSERT INTO places(category_id,name,province,latitude,longitude,source_type,status) VALUES($category,'Pin fixture A','Test',11.9419,108.4483,'ADMIN','ACTIVE') RETURNING id"
$placeB=Sql "INSERT INTO places(category_id,name,province,latitude,longitude,source_type,status) VALUES($category,'Pin fixture B','Test',11.9037,108.4369,'ADMIN','ACTIVE') RETURNING id"
$new=Api POST '/trips' $a @{title='Stop/time regression';startDate='2026-12-01';endDate='2026-12-02'} 201
$n=$new.id
$null=Api GET "/trips/$n" $outside $null 404
$null=Api POST "/trips/$n/stops" $a @{placeId=9223372036854775807} 404
$one=Api POST "/trips/$n/stops" $a @{placeId=[long]$placeA;dayNo=1;plannedStartAt='2026-12-01T08:00:00+07:00';plannedEndAt='2026-12-01T09:00:00+07:00'} 201
Check ($one.stops[0].hasCompleteInterval) 'Stop time interval lost'
$null=Api POST "/trips/$n/stops" $a @{placeId=[long]$placeA;dayNo=1} 400
$two=Api POST "/trips/$n/stops" $a @{placeId=[long]$placeB;dayNo=1} 201
$three=Api POST "/trips/$n/stops" $a @{placeId=[long]$placeA;dayNo=1} 201
$cleared=Api PATCH "/trips/$n/stops/$($one.stops[0].id)" $a @{clearTime=$true}
Check (!$cleared.stops[0].plannedStartAt -and !$cleared.stops[0].hasCompleteInterval) 'Clear time failed'
$orders=@(); $order=1
foreach($stop in @($three.stops[2],$three.stops[1],$three.stops[0])) { $orders+=@{stopId=$stop.id;dayNo=1;orderNo=$order}; $order++ }
$reordered=Api PATCH "/trips/$n/stops/reorder" $a @{stops=$orders}
Check ($reordered.stops[0].id -eq $three.stops[2].id) 'Occurrence reorder failed'
$optimized=Api POST "/trips/$n/stops/optimize" $a @{dayNo=1}
Check ($optimized.stops.Count -eq 3) 'Optimize lost stops'
$null=Api DELETE "/trips/$n/stops/$($optimized.stops[2].id)" $a $null 204
$found=@(Api GET '/places/search?q=Pin%20fixture' $a)
Check ($found.Count -ge 2) 'Place search regression'
$detail=Api GET "/places/$placeA" $a
Check (@($detail.media).Count -eq 0) 'No-media detail regression'
$route=Api POST '/routes/directions' $a @{originPlaceId="$placeA";destinationPlaceId="$placeB"}
Check ($route.geometry.Count -gt 1 -and $route.distanceMeters -gt 0 -and $route.durationSeconds -gt 0) 'Real Mapbox route regression'
Check ((Sql "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='public' AND ((table_name='trips' AND column_name IN ('status','started_at','completed_at')) OR (table_name='trip_members' AND column_name IN ('location_sharing_enabled','location_sharing_updated_at')))") -eq '0') 'Obsolete fields remain'
Check ((Sql "SELECT COUNT(*) FROM flyway_schema_history WHERE success=TRUE AND version IN ('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16')") -eq '16') 'Missing pin-centric baseline V1-V16'
[ordered]@{result='PASS';database=$Database;flyway='V1-V16 baseline present (later additive migrations allowed)';pinAuthority='FG+BG';snapshot='UPSERT+last-known after unpin/switch; departure/archive cleanup';sse='updated+unavailable';isolation='own user and own Trip';delete='soft archive+retained chat history';oldEndpoints='removed';notifications='unchanged';routeDistanceMeters=$route.distanceMeters;routeDurationSeconds=$route.durationSeconds;geometryPoints=$route.geometry.Count;stopTimeReorderOptimize='PASS';placeSearchDetail='PASS'} | ConvertTo-Json
