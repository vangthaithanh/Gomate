param([string]$BaseUrl = 'http://127.0.0.1:18083/api/v1')
$ErrorActionPreference = 'Stop'
$uri = [uri]$BaseUrl
if ($uri.Host -notin @('127.0.0.1', 'localhost') -or $uri.Port -notin @(18083,18084,18085,18086,18087)) {
    throw 'Only run against isolated verification API ports 18083-18087 with push disabled.'
}
function Api([string]$Method, [string]$Path, $Session, $Body = $null, [int]$Expected = 200) {
    $args = @{Method=$Method; Uri=$BaseUrl+$Path; TimeoutSec=20; SkipHttpErrorCheck=$true}
    if ($Session) { $args.Headers=@{Authorization='Bearer '+$Session.accessToken} }
    if ($null -ne $Body) { $args.ContentType='application/json'; $args.Body=ConvertTo-Json $Body -Depth 6 }
    $response=Invoke-WebRequest @args
    if ([int]$response.StatusCode -ne $Expected) { throw "$Method $Path expected $Expected but got $($response.StatusCode)" }
    if ($response.Content) { return ConvertFrom-Json $response.Content }
}
function User {
    $suffix=[guid]::NewGuid().ToString('N')
    Api 'POST' '/auth/register' $null @{email="$suffix@example.invalid"; password="TestOnly123!$suffix"; nickname="ml_$($suffix.Substring(0,12))"} 201
}
function Check($Condition, [string]$Message) { if (!$Condition) { throw $Message } }
$results=@()
foreach ($mode in @('leave','remove')) {
    $a=User; $b=User; $c=User
    $trip=Api 'POST' '/trips' $a @{title="Lifecycle $mode fixture";startDate='2026-12-01';endDate='2026-12-02';selectedMemberIds=@($b.user.id)} 201
    $id=$trip.id; $oldInvite=$trip.pendingInvitations[0].invitationId
    $group=Api 'POST' "/trip-invitations/$oldInvite/accept" $b
    $c1=$group.linkedConversationId
    Check ($group.tripType -eq 'GROUP' -and $group.memberCount -eq 2 -and $c1) 'Expected initial GROUP with A/B and C1'
    $null=Api 'POST' "/conversations/$c1/messages" $a @{text="Retain history for $mode"} 201
    $null=Api 'POST' "/trips/$id/pin" $b
    $null=Api 'PUT' "/trips/$id/location" $b @{latitude=11.94;longitude=108.44}
    if ($mode -eq 'leave') { $null=Api 'DELETE' "/trips/$id/members/me" $b $null 204 }
    else { $null=Api 'DELETE' "/trips/$id/members/$($b.user.id)" $a }
    $personal=Api 'GET' "/trips/$id" $a
    Check ($personal.tripType -eq 'PERSONAL' -and $personal.memberCount -eq 1 -and !$personal.linkedConversationId) 'Last-member transition failed'
    $null=Api 'GET' "/trips/$id" $b $null 404
    $null=Api 'GET' "/conversations/$c1" $b $null 404
    $null=Api 'POST' "/conversations/$c1/messages" $b @{text='denied'} 404
    $null=Api 'GET' "/trips/$id/locations" $b $null 404
    Check (@(Api 'GET' "/trips/$id/locations" $a).Count -eq 0) 'Removed member snapshot is still visible'
    $null=Api 'PUT' "/trips/$id/location" $b @{latitude=11.94;longitude=108.44} 404
    $null=Api 'POST' "/trips/$id/pin" $b $null 404
    $null=Api 'DELETE' "/trips/$id/members/me" $a $null 422
    $null=Api 'DELETE' "/trips/$id/members/me" $b $null 404
    $null=Api 'DELETE' "/trips/$id/members/$($b.user.id)" $a $null 404
    $history=@(Api 'GET' '/trip-invitations/incoming?status=ACCEPTED' $b)
    Check (@($history|Where-Object invitationId -eq $oldInvite).Count -eq 1) 'Invitation history changed'
    $invite=Api 'POST' "/trips/$id/invitations" $a @{inviteeUserId=$c.user.id} 201
    $next=Api 'POST' "/trip-invitations/$($invite.invitationId)/accept" $c
    $c2=$next.linkedConversationId
    Check ($next.tripType -eq 'GROUP' -and $next.memberCount -eq 2 -and $c2 -and $c2 -ne $c1) 'Later lifecycle did not create a new chat'
    $null=Api 'GET' "/conversations/$c1" $c $null 404
    $null=Api 'GET' "/conversations/$c1/messages" $c $null 404
    $null=Api 'GET' "/conversations/$c1" $a $null 404
    $null=Api 'GET' "/conversations/$c2" $c
    Check (@(Api 'GET' "/trips/$id/locations" $a).Count -eq 0) 'Old location sharing was inherited'
    $null=Api 'POST' "/trip-invitations/$oldInvite/accept" $b $null 404
    $results += [ordered]@{mode=$mode;tripId=$id;leaderId=$a.user.id;removedId=$b.user.id;newMemberId=$c.user.id;oldChat=$c1;newChat=$c2;beforeType='GROUP';afterRemovalType=$personal.tripType;afterJoinType=$next.tripType;newMemberOldChatStatus=404;result='PASS'}
}

# Real PostgreSQL row-lock race via two simultaneous HTTP requests.
$a=User; $b=User
$trip=Api 'POST' '/trips' $a @{title='Concurrent membership fixture';startDate='2026-12-01';endDate='2026-12-02';selectedMemberIds=@($b.user.id)} 201
$null=Api 'POST' "/trip-invitations/$($trip.pendingInvitations[0].invitationId)/accept" $b
$client=[System.Net.Http.HttpClient]::new()
$client.Timeout=[timespan]::FromSeconds(20)
$leave=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Delete,"$BaseUrl/trips/$($trip.id)/members/me")
$remove=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Delete,"$BaseUrl/trips/$($trip.id)/members/$($b.user.id)")
$leave.Headers.Authorization=[System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$b.accessToken)
$remove.Headers.Authorization=[System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$a.accessToken)
try {
    $t1=$client.SendAsync($leave); $t2=$client.SendAsync($remove)
    $r1=$t1.GetAwaiter().GetResult(); $r2=$t2.GetAwaiter().GetResult()
    $codes=@([int]$r1.StatusCode,[int]$r2.StatusCode)
    Check (($codes[0] -eq 204 -and $codes[1] -eq 404) -or ($codes[0] -eq 404 -and $codes[1] -eq 200)) "Unsafe concurrent result $codes"
    $after=Api 'GET' "/trips/$($trip.id)" $a
    Check ($after.tripType -eq 'PERSONAL' -and $after.memberCount -eq 1 -and !$after.linkedConversationId) 'Race corrupted membership'
    $results += [ordered]@{mode='race';tripId=$trip.id;httpStatuses=$codes;result='PASS'}
} finally {
    if ($r1) { $r1.Dispose() }; if ($r2) { $r2.Dispose() }
    $leave.Dispose(); $remove.Dispose(); $client.Dispose()
}
ConvertTo-Json -InputObject @($results) -Depth 5
