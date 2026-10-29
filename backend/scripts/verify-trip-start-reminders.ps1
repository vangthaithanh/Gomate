param(
    [string]$BaseUrl = 'http://127.0.0.1:18088/api/v1',
    [Parameter(Mandatory)][string]$Database,
    [Parameter(Mandatory)][string]$ApiContainer
)
$ErrorActionPreference = 'Stop'
throw 'SUPERSEDED: this is the historical V17 T-60/T-30 verifier. Use verify-trip-date-reminders.ps1 for V25; never reactivate the old scheduling policy.'
$uri = [uri]$BaseUrl
if ($uri.Host -notin @('localhost','127.0.0.1') -or $uri.Port -notin @(18088,18089) -or
    $Database -notmatch '^gomate_reminder_(clean|upgrade)_[a-z0-9_]+$' -or
    $ApiContainer -notmatch '^gomate-reminder-(clean|upgrade)$') {
    throw 'Isolated reminder database/API only; never point this script at user data.'
}
function Check($Value,[string]$Message) { if (!$Value) { throw $Message } }
function Sql([string]$Query) {
    $r=docker compose exec -T postgres psql -U gomate -d $Database -qAt -v ON_ERROR_STOP=1 -c $Query
    if ($LASTEXITCODE -ne 0) { throw 'SQL verification failed' }
    ($r -join "`n").Trim()
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
    $key=[guid]::NewGuid().ToString('N')
    Api POST '/auth/register' $null @{email="$key@example.invalid";password="TestOnly123!$key";nickname="rem_$($key.Substring(0,12))"} 201
}
function WaitFor($Test,[string]$Message,[int]$Seconds=40) {
    $until=[DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        if (& $Test) { return }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $until)
    throw $Message
}
function Plan($User) {
    $context=Api GET '/trips/time-context?timezone=Asia%2FHo_Chi_Minh' $User
    $wall=[datetime]::Parse($context.localNow,[cultureinfo]::InvariantCulture)
    $future=$wall.AddHours(3)
    @{title='Isolated reminder verification';startDate=$future.ToString('yyyy-MM-dd');endDate=$future.ToString('yyyy-MM-dd');timezone='Asia/Ho_Chi_Minh';plannedStartTime=$future.ToString('HH:mm')}
}

Check ((Sql 'SELECT COUNT(*) FROM flyway_schema_history WHERE success=TRUE') -eq '17') 'Expected V1-V17'
Check ((Sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'") -eq '25') 'Unexpected table added'
$a=User; $b=User; $c=User
$context=Api GET '/trips/time-context' $a
$today=[datetime]::Parse($context.today,[cultureinfo]::InvariantCulture)
$plain=Api POST '/trips' $a @{title='No optional hour';startDate=$context.today;endDate=$context.today} 201
Check ($null -eq $plain.plannedStartTime) 'No-hour Trip invented an hour'
Check ((Sql "SELECT COUNT(*) FROM trip_reminders WHERE trip_id='$($plain.id)'") -eq '0') 'No-hour Trip created reminder'
$null=Api POST '/trips' $a @{title='Invalid past date';startDate=$today.AddDays(-1).ToString('yyyy-MM-dd');endDate=$context.today} 400
$wall=[datetime]::Parse($context.localNow,[cultureinfo]::InvariantCulture)
$null=Api POST '/trips' $a @{title='Invalid minute';startDate=$context.today;endDate=$context.today;plannedStartTime=$wall.ToString('HH:mm')} 400
$body=Plan $a; $body.selectedMemberIds=@($b.user.id,$c.user.id)
$trip=Api POST '/trips' $a $body 201
$id=$trip.id
Check ($trip.plannedStartTime.StartsWith($body.plannedStartTime)) 'Local hour changed in round trip'
Check ($trip.pendingInvitations.Count -eq 2) 'Create invitations changed'
Check ((Sql "SELECT COUNT(*) FROM trip_reminders WHERE trip_id='$id'") -eq '2') 'Pending invitees scheduled reminders'
$invite=@($trip.pendingInvitations | Where-Object inviteeUserId -eq $b.user.id)[0].invitationId
$group=Api POST "/trip-invitations/$invite/accept" $b
Check ($group.memberCount -eq 2 -and $group.linkedConversationId) 'Accept/group chat regression'
Check ((Sql "SELECT COUNT(*) FROM trip_reminders WHERE trip_id='$id'") -eq '4') 'Accepted member not scheduled'
$null=Api PATCH "/trips/$id" $b @{plannedStartTime='23:59'} 403
$null=Api GET "/trips/$id" $c $null 404
$other=Api POST '/trips' $b @{title='Independent pin';startDate=$context.today;endDate=$context.today} 201
$null=Api POST "/trips/$($other.id)/pin" $b

$client=[System.Net.Http.HttpClient]::new()
$client.Timeout=[TimeSpan]::FromSeconds(90)
$req=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get,"$BaseUrl/notifications/stream")
$req.Headers.Authorization=[System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$a.accessToken)
$response=$null; $reader=$null
try {
    $response=$client.SendAsync($req,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    Check ([int]$response.StatusCode -eq 200) 'SSE unavailable'
    $reader=[System.IO.StreamReader]::new($response.Content.ReadAsStream())
    # Controlled isolated-DB due-queue fixture; production clock/endpoints remain unchanged.
    $null=Sql "UPDATE trip_reminders SET remind_at=CURRENT_TIMESTAMP-INTERVAL '1 second' WHERE trip_id='$id' AND status='PENDING'"
    WaitFor { (Sql "SELECT COUNT(*) FROM trip_reminders WHERE trip_id='$id' AND status='SENT'") -eq '4' } 'Scheduler failed to send current accepted members'
    $found=$false; $until=[datetime]::UtcNow.AddSeconds(20)
    while (!$found -and [datetime]::UtcNow -lt $until) {
        $line=$reader.ReadLineAsync()
        Check ($line.Wait(20000)) 'SSE event timeout'
        Check ($null -ne $line.Result) 'SSE closed'
        $found=$line.Result -eq 'event:notification'
    }
    Check $found 'Reminder did not publish through SSE'
} finally {
    if ($reader) { $reader.Dispose() }; if ($response) { $response.Dispose() }
    $req.Dispose(); $client.Dispose()
}
$countQuery="SELECT COUNT(*) FROM notifications n JOIN trip_reminders r ON n.entity_type='TRIP_REMINDER' AND n.entity_id=r.id::text WHERE r.trip_id='$id'"
Check ((Sql $countQuery) -eq '4') 'Expected four distinct durable reminder notifications'
Check ((Sql "SELECT COUNT(*) FROM notifications WHERE user_id='$($c.user.id)' AND type='TRIP_START_REMINDER'") -eq '0') 'Pending invitee received reminder'
$inbox=Api GET '/notifications' $a
$notices=@($inbox.items | Where-Object type -eq 'TRIP_START_REMINDER')
Check ($notices.Count -eq 2 -and ($notices.reminderId | Sort-Object -Unique).Count -eq 2) 'Offsets collapsed to one notification'
Check (@($notices | Where-Object { $_.tripId -ne $id -or !$_.plannedStartAt -or $_.invitationId }).Count -eq 0) 'Reminder API metadata incorrect'
$one=Api GET "/notifications/$($notices[0].id)" $a
Check ($one.tripId -eq $id) 'Tap target did not resolve current Trip'
$null=Api GET "/notifications/$($notices[0].id)" $c $null 404
Check ((Api GET '/trips/pinned' $b).trip.id -eq $other.id) 'Scheduler changed independent pin'
Check ($null -eq (Api GET '/trips/pinned' $a).trip) 'Scheduler auto-pinned owner'
$history=Sql "SELECT json_agg(r ORDER BY id)::text FROM trip_reminders r WHERE trip_id='$id' AND status='SENT'"
$null=Api PATCH "/trips/$id" $a @{clearStartTime=$true}
$edited=Plan $a
$null=Api PATCH "/trips/$id" $a @{plannedStartTime=$edited.plannedStartTime}
Check ((Sql "SELECT json_agg(r ORDER BY id)::text FROM trip_reminders r WHERE trip_id='$id' AND status='SENT'") -eq $history) 'SENT history was rewritten'
$null=Api DELETE "/trips/$id/members/me" $b $null 204
Check ($null -eq (Api GET "/notifications/$((Api GET '/notifications' $b).items.Where({$_.type -eq 'TRIP_START_REMINDER'})[0].id)" $b).tripId) 'Left member still has reminder navigation target'

# Pending queue survives a real API process restart and may run late before planned start.
$restartTrip=Api POST '/trips' $a (Plan $a) 201
$restart=$restartTrip.id
$null=docker stop $ApiContainer
Check ($LASTEXITCODE -eq 0) 'Cannot stop isolated API'
$null=Sql "UPDATE trip_reminders SET remind_at=CURRENT_TIMESTAMP-INTERVAL '1 minute' WHERE trip_id='$restart'"
Check ((Sql "SELECT COUNT(*) FROM trip_reminders WHERE trip_id='$restart' AND status='PENDING'") -eq '2') 'Pending state lost during downtime'
$null=docker start $ApiContainer
Check ($LASTEXITCODE -eq 0) 'Cannot restart isolated API'
WaitFor { try { $null=Api GET '/trips/time-context' $a; $true } catch { $false } } 'API did not restart' 90
WaitFor { (Sql "SELECT COUNT(*) FROM trip_reminders WHERE trip_id='$restart' AND status='SENT'") -eq '2' } 'Late pending reminders lost after restart'
Start-Sleep -Seconds 16
Check ((Sql $countQuery) -eq '4') 'Restart/scheduler resent SENT events'
Check ((Sql "SELECT COUNT(*) FROM notifications n JOIN trip_reminders r ON n.entity_id=r.id::text WHERE n.type='TRIP_START_REMINDER' AND r.trip_id='$restart'") -eq '2') 'Restart duplicated/lost offsets'
$null=Api DELETE "/trips/$restart" $a $null 204
$historical=Api PATCH "/trips/$($plain.id)" $a @{title='Historical fixture metadata'}
$null=Sql "UPDATE trips SET start_date='2020-01-01',end_date='2020-01-02' WHERE id='$($plain.id)'"
$null=Api PATCH "/trips/$($plain.id)" $a @{title='Historical metadata remains editable'}
$null=Api PATCH "/trips/$($plain.id)" $a @{plannedStartTime='08:00'} 400
[ordered]@{result='PASS';database=$Database;flyway='V1-V17';tables=25;optionalHour='null+round-trip+clear';dateValidation='past/current-minute+historical';groupRecipients=2;pendingRecipientReminders=0;reminderNotifications=4;restartNotifications=2;sse='AFTER_COMMIT notification';independentPin='unchanged';sentHistory='unchanged';restartIdempotency='PASS';push='disabled in isolated API; gateway covered by backend tests';device='PENDING_MANUAL'} | ConvertTo-Json
