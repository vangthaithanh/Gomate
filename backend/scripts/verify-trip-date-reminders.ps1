param(
 [Parameter(Mandatory)][string]$Database,
 [Parameter(Mandatory)][string]$ApiContainer,
 [Parameter(Mandatory)][string]$BaseUrl
)
$ErrorActionPreference='Stop'
$uri=[uri]$BaseUrl
if($Database -notmatch '^gomate_trip_date_(clean|upgrade)_[a-z0-9_]+$' -or
 $ApiContainer -notmatch '^gomate-trip-date-(clean|upgrade)$' -or
 $uri.Host -notin @('127.0.0.1','localhost') -or $uri.Port -notin @(18097,18098)) {
 throw 'Only isolated V25 databases/APIs allowed. Never run against the normal API.'
}
function Check($condition,$message) {if(!$condition){throw $message}}
function Sql($query) {
 $rows=docker compose exec -T postgres psql -U gomate -d $Database -qAt -v ON_ERROR_STOP=1 -c $query
 if($LASTEXITCODE -ne 0){throw 'Isolated diagnostic SQL failed'}
 ($rows -join "`n").Trim()
}
function Api($method,$path,$user,$body=$null,$expected=200) {
 $p=@{Method=$method;Uri=$BaseUrl+$path;TimeoutSec=30;SkipHttpErrorCheck=$true}
 if($user){$p.Headers=@{Authorization='Bearer '+$user.accessToken}}
 if($null -ne $body){$p.ContentType='application/json; charset=utf-8';$p.Body=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 8))}
 $r=Invoke-WebRequest @p
 Check ([int]$r.StatusCode -eq $expected) "$method $path expected $expected; got $([int]$r.StatusCode)"
 if($r.Content){$r.Content|ConvertFrom-Json}
}
function User {
 $key=[guid]::NewGuid().ToString('N')
 Api POST '/auth/register' $null @{email="$key@example.invalid";nickname="date_$($key.Substring(0,12))";password="TestOnly123!$key"} 201
}
Check ((Sql "SELECT max(installed_rank) FROM flyway_schema_history WHERE success") -eq '25') 'Expected V25'
Check ((Sql "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' AND table_name<>'flyway_schema_history'") -eq '37') 'Unexpected business table count'
$a=User;$b=User;$c=User
$context=Api GET '/trips/time-context' $a
$today=[datetime]::Parse($context.today,[cultureinfo]::InvariantCulture)
$date=$today.AddDays(4).ToString('yyyy-MM-dd')
$trip=Api POST '/trips' $a @{title='Date reminder isolated fixture';startDate=$date;endDate=$date;timezone='Asia/Ho_Chi_Minh';selectedMemberIds=@($b.user.id,$c.user.id)} 201
$id=$trip.id
Check (-not ($trip.PSObject.Properties.Name -contains 'plannedStartTime')) 'Legacy hour exposed'
Check ((Sql "SELECT count(*) FROM trip_reminders WHERE trip_id='$id' AND status='PENDING' AND days_before IN(1,2)") -eq '2') 'Owner did not get two slots'
Check ((Sql "SELECT count(*) FROM trip_reminders WHERE trip_id='$id' AND recipient_user_id<>'$($a.user.id)'") -eq '0') 'Pending invitees scheduled'
Check ((Sql "SELECT count(*) FROM trip_reminders WHERE trip_id='$id' AND reminder_date=trip_start_date-days_before AND (remind_at AT TIME ZONE reminder_timezone)::date=reminder_date AND (remind_at AT TIME ZONE reminder_timezone)::time='20:00'::time AND offset_minutes IS NULL AND planned_start_at IS NULL") -eq '2') 'Wrong date/zone/time metadata'
$invitation=@($trip.pendingInvitations|Where-Object inviteeUserId -eq $b.user.id)[0].invitationId
$group=Api POST "/trip-invitations/$invitation/accept" $b
Check ($group.memberCount -eq 2 -and $group.linkedConversationId) 'Accepted membership/chat regression'
Check ((Sql "SELECT count(*) FROM trip_reminders WHERE trip_id='$id' AND status='PENDING'") -eq '4') 'Accepted member schedule missing'
$null=Api PATCH "/trips/$id" $b @{startDate=$date} 403
$null=Api PATCH "/trips/$id" $a @{plannedStartTime='08:00'} 400
$null=Api PATCH "/trips/$id" $a @{clearStartTime=$true} 400
$before=Sql "SELECT string_agg(id::text,',' ORDER BY id) FROM trip_reminders WHERE trip_id='$id' AND status='PENDING'"
$null=Api POST "/trips/$id/pin" $a
$null=Api GET "/trips/$id" $a
$null=Api DELETE "/trips/$id/pin" $a $null 204
$null=Api PATCH "/trips/$id" $a @{title='Renamed without scheduling effect'}
Check ((Sql "SELECT string_agg(id::text,',' ORDER BY id) FROM trip_reminders WHERE trip_id='$id' AND status='PENDING'") -eq $before) 'Pin/view/metadata changed reminder identities'
$null=docker restart $ApiContainer
Check ($LASTEXITCODE -eq 0) 'Cannot restart isolated API'
$ready=$false
for($i=0;$i -lt 60;$i++) {
 try {$null=Api GET '/health' $null;$ready=$true;break} catch {Start-Sleep -Milliseconds 500}
}
Check $ready 'Isolated API restart failed'
Check ((Sql "SELECT string_agg(id::text,',' ORDER BY id) FROM trip_reminders WHERE trip_id='$id' AND status='PENDING'") -eq $before) 'Restart lost or duplicated pending queue'
$null=Api DELETE "/trips/$id/members/me" $b $null 204
Check ((Sql "SELECT count(*) FROM trip_reminders WHERE trip_id='$id' AND recipient_user_id='$($b.user.id)' AND status='PENDING'") -eq '0') 'Leave did not cancel pending'
$null=Api DELETE "/trips/$id" $a $null 204
Check ((Sql "SELECT count(*) FROM trip_reminders WHERE trip_id='$id' AND status='PENDING'") -eq '0') 'Archive did not cancel pending'
Check ((Sql "SELECT count(*) FROM notifications WHERE type='TRIP_START_REMINDER' AND entity_id IN(SELECT id::text FROM trip_reminders WHERE trip_id='$id')") -eq '0') 'Future reminders sent early'
[ordered]@{result='PASS';database=$Database;flyway='V25';businessTables=37;slotsPerMember=2;pendingExcluded=$true;localHour='20:00';sameDayTrip=$true;legacyHourRejected=$true;pinIndependent=$true;restartQueueStable=$true;leaveArchiveCancel=$true;deadlineDelivery='frozen-clock backend tests';device='PENDING_MANUAL'}|ConvertTo-Json
