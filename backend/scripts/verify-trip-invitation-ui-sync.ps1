param([string]$BaseUrl = 'http://127.0.0.1:18082/api/v1')

$ErrorActionPreference = 'Stop'
if (([uri]$BaseUrl).Host -notin @('127.0.0.1', 'localhost')) {
    throw 'This fixture test is intended for an isolated local test database.'
}

function Assert-Result([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Call-Api([string]$Method, [string]$Path, $Session, $Body = $null, [int]$Expected = 200) {
    $headers = @{}
    if ($null -ne $Session) { $headers.Authorization = 'Bearer ' + $Session.accessToken }
    $options = @{
        Method = $Method; Uri = $BaseUrl + $Path; Headers = $headers
        SkipHttpErrorCheck = $true; TimeoutSec = 30
    }
    if ($null -ne $Body) { $options.ContentType = 'application/json'; $options.Body = ConvertTo-Json $Body -Depth 10 }
    $response = Invoke-WebRequest @options
    Assert-Result ($response.StatusCode -eq $Expected) "$Method $Path returned $($response.StatusCode), expected $Expected"
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) { return ConvertFrom-Json $response.Content }
}

function New-TestUser {
    $suffix = [guid]::NewGuid().ToString('N')
    Call-Api 'POST' '/auth/register' $null @{
        email = "ui-invite-$suffix@example.invalid"
        nickname = 'invite_' + $suffix.Substring(0, 10)
        password = 'TestOnly123!' + $suffix
    } 201
}

# Creates disposable users/trip. Run against the isolated verification DB.
$a = New-TestUser
$b = New-TestUser
$c = New-TestUser
$aId = [string]$a.user.id
$bId = [string]$b.user.id
$cId = [string]$c.user.id
$trip = Call-Api 'POST' '/trips' $a @{
    title = 'Invitation UI sync verification'; startDate = '2026-12-01'; endDate = '2026-12-02'
    selectedMemberIds = @($bId, $cId, $bId)
} 201
$tripId = [string]$trip.id
Assert-Result ($trip.tripType -eq 'PERSONAL' -and $trip.memberCount -eq 1) 'Create must persist creator only as PERSONAL'
Assert-Result ($null -eq $trip.linkedConversationId) 'Create must not create group chat'
Assert-Result ($trip.pendingInvitations.Count -eq 2) 'Create must issue two unique invitations'

$bInbox = Call-Api 'GET' '/notifications' $b
$cInbox = Call-Api 'GET' '/notifications' $c
$bItem = $bInbox.items[0]
$cItem = $cInbox.items[0]
Assert-Result ($bItem.invitationStatus -eq 'PENDING' -and $cItem.invitationStatus -eq 'PENDING') 'Inbox must show server PENDING state'
Assert-Result ($bItem.id -ne $bItem.invitationId -and $bItem.id -ne $tripId) 'Notification/invitation/trip IDs must be separate'
Call-Api 'GET' "/trips/$tripId" $b $null 404 | Out-Null
Call-Api 'GET' "/notifications/$($bItem.id)" $c $null 404 | Out-Null
Call-Api 'POST' "/trip-invitations/$($bItem.invitationId)/accept" $c $null 403 | Out-Null
$read = Call-Api 'PATCH' "/notifications/$($bItem.id)/read" $b
Assert-Result ($read.isRead -and $read.invitationStatus -eq 'PENDING') 'Reading must not accept'

Call-Api 'POST' "/trips/$tripId/members" $a @{ selectedMemberIds = @($bId, $cId) } | Out-Null
$bAgain = Call-Api 'GET' '/notifications' $b
Assert-Result ($bAgain.total -eq 1) 'Repeated send must not duplicate inbox records'

$first = Call-Api 'POST' "/trip-invitations/$($bItem.invitationId)/accept" $b
Assert-Result ($first.tripType -eq 'GROUP' -and $first.memberCount -eq 2 -and $null -ne $first.linkedConversationId) 'First accept must create GROUP and linked chat'
$second = Call-Api 'POST' "/trip-invitations/$($cItem.invitationId)/accept" $c
Assert-Result ($second.memberCount -eq 3 -and $second.linkedConversationId -eq $first.linkedConversationId) 'Second accept must reuse the same chat'
$repeated = Call-Api 'POST' "/trip-invitations/$($bItem.invitationId)/accept" $b
Assert-Result ($repeated.memberCount -eq 3 -and $repeated.linkedConversationId -eq $first.linkedConversationId) 'Repeated accept must be idempotent'
$resolved = Call-Api 'GET' "/notifications/$($bItem.id)" $b
Assert-Result ($resolved.invitationStatus -eq 'ACCEPTED') 'New read must resolve accepted status from server'
$ownerInbox = Call-Api 'GET' '/notifications' $a
Assert-Result ($ownerInbox.total -eq 2) 'Inviter must receive exactly two accepted events'
Call-Api 'GET' "/trips/$tripId" $b | Out-Null

Call-Api 'PATCH' '/users/me/profile' $a @{ fullName = 'UI Sync Test A'; bio = 'Disposable integration test' } | Out-Null
$profile = Call-Api 'GET' '/users/me' $a
Assert-Result ($profile.fullName -eq 'UI Sync Test A') 'Real profile editing must still persist'
Call-Api 'PUT' "/users/$bId/follow" $a | Out-Null
Call-Api 'PUT' "/users/$aId/follow" $b | Out-Null
$friends = Call-Api 'GET' "/users/$aId/mutual-friends" $c
Assert-Result ($friends.total -eq 1 -and $friends.items[0].userId -eq $bId -and -not $friends.items[0].followingByMe) 'Profile list must belong to target and relation must belong to viewer'

$cancelTrip = Call-Api 'POST' '/trips' $a @{
    title = 'Cancellation verification'; startDate = '2026-12-01'; endDate = '2026-12-02'
    selectedMemberIds = @($bId, $cId)
} 201
$cancelTripId = [string]$cancelTrip.id
$bPending = @($cancelTrip.pendingInvitations | Where-Object inviteeUserId -eq $bId)[0]
$cPending = @($cancelTrip.pendingInvitations | Where-Object inviteeUserId -eq $cId)[0]
$cancelUrl = "/trips/$cancelTripId/invitations/$($bPending.invitationId)"
Call-Api 'DELETE' $cancelUrl $c $null 404 | Out-Null
$cancelled = Call-Api 'DELETE' $cancelUrl $a
Assert-Result ($cancelled.pendingInvitations.Count -eq 1 -and $cancelled.memberCount -eq 1 -and $cancelled.tripType -eq 'PERSONAL') 'Cancel must not create or remove membership'
Call-Api 'DELETE' $cancelUrl $a | Out-Null
Call-Api 'POST' "/trip-invitations/$($bPending.invitationId)/accept" $b $null 409 | Out-Null
$cancelInbox = Call-Api 'GET' '/notifications' $b
$cancelEvent = @($cancelInbox.items | Where-Object invitationId -eq $bPending.invitationId)[0]
Assert-Result ($cancelEvent.invitationStatus -eq 'CANCELLED') 'Existing notification must resolve CANCELLED'
$newInvite = Call-Api 'POST' "/trips/$cancelTripId/invitations" $a @{inviteeUserId=$bId} 201
Assert-Result ($newInvite.invitationId -ne $bPending.invitationId) 'Reinvite must have a new business ID'
Call-Api 'DELETE' $cancelUrl $a | Out-Null
$afterReinvite = Call-Api 'GET' "/trips/$cancelTripId" $a
Assert-Result ($afterReinvite.pendingInvitations.Count -eq 2) 'Old cancel retry must not cancel the new invitation'
$joined = Call-Api 'POST' "/trip-invitations/$($newInvite.invitationId)/accept" $b
Call-Api 'DELETE' "/trips/$cancelTripId/invitations/$($newInvite.invitationId)" $a $null 409 | Out-Null
Call-Api 'DELETE' "/trips/$cancelTripId/invitations/$($cPending.invitationId)" $b $null 403 | Out-Null
$groupAfterCancel = Call-Api 'DELETE' "/trips/$cancelTripId/invitations/$($cPending.invitationId)" $a
Assert-Result ($groupAfterCancel.memberCount -eq 2 -and $groupAfterCancel.linkedConversationId -eq $joined.linkedConversationId) 'Group cancellation must preserve accepted members and linked chat'

[ordered]@{
    result = 'PASS'; tripId = $tripId; initialType = $trip.tripType; initialMembers = $trip.memberCount
    initialPendingInvitations = $trip.pendingInvitations.Count; finalMembers = $second.memberCount
    sameConversation = ($first.linkedConversationId -eq $second.linkedConversationId)
    readDoesNotAccept = $true; idempotentSend = $true; idempotentAccept = $true
    inviterAcceptedNotifications = $ownerInbox.total; profileAndFollow = 'PASS'
    leaderPendingCancellation = 'PASS'; cancelledCannotAccept = $true; cancellationRetrySafe = $true
    reinviteHasNewId = $true; memberCancellationForbidden = $true; acceptedMembershipPreserved = $true
} | ConvertTo-Json
