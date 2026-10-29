param([string]$BaseUrl = 'http://127.0.0.1:18083/api/v1')

$ErrorActionPreference = 'Stop'
$uri = [uri]$BaseUrl
if ($uri.Host -notin @('127.0.0.1', 'localhost') -or $uri.Port -ne 18083) {
    throw 'Run only against the disposable realtime verification API on port 18083.'
}

function Assert-Result([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Call-Api([string]$Method, [string]$Path, $Session, $Body = $null, [int]$Expected = 200) {
    $headers = @{}
    if ($null -ne $Session) { $headers.Authorization = 'Bearer ' + $Session.accessToken }
    $options = @{ Method = $Method; Uri = $BaseUrl + $Path; Headers = $headers; SkipHttpErrorCheck = $true; TimeoutSec = 10 }
    if ($null -ne $Body) { $options.ContentType = 'application/json'; $options.Body = ConvertTo-Json $Body -Depth 8 }
    $response = Invoke-WebRequest @options
    Assert-Result ($response.StatusCode -eq $Expected) "$Method $Path returned $($response.StatusCode), expected $Expected"
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) { return ConvertFrom-Json $response.Content }
}

function New-TestUser {
    $suffix = [guid]::NewGuid().ToString('N')
    Call-Api 'POST' '/auth/register' $null @{ email = "rt-$suffix@example.invalid"; nickname = 'rt_' + $suffix.Substring(0, 12); password = 'TestOnly123!' + $suffix } 201
}

function Open-Stream($Session) {
    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, "$BaseUrl/notifications/stream")
    $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Session.accessToken)
    $request.Headers.Accept.ParseAdd('text/event-stream')
    $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).WaitAsync([TimeSpan]::FromSeconds(6)).GetAwaiter().GetResult()
    Assert-Result ($response.StatusCode -eq 200) 'SSE connection must be authenticated and open'
    $reader = [System.IO.StreamReader]::new($response.Content.ReadAsStream())
    return [pscustomobject]@{ Client = $client; Request = $request; Response = $response; Reader = $reader }
}

function Close-Stream($Stream) {
    if ($null -eq $Stream) { return }
    $Stream.Reader.Dispose()
    $Stream.Response.Dispose()
    $Stream.Request.Dispose()
    $Stream.Client.Dispose()
}

function Read-Frame($Stream) {
    $eventType = ''
    $data = ''
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ([DateTime]::UtcNow -lt $deadline) {
        $line = $Stream.Reader.ReadLineAsync().WaitAsync($deadline - [DateTime]::UtcNow).GetAwaiter().GetResult()
        if ($null -eq $line) { throw 'SSE closed unexpectedly' }
        if ($line.Length -eq 0 -and $eventType) {
            return [pscustomobject]@{ Type = $eventType; Data = $(if ($data) { ConvertFrom-Json $data } else { $null }) }
        }
        if ($line.StartsWith('event:')) { $eventType = $line.Substring(6).Trim() }
        if ($line.StartsWith('data:')) { $data += $line.Substring(5).TrimStart() }
    }
    throw 'Timed out waiting for SSE frame'
}

function Read-Signal($Stream, [string]$Kind, [string]$NotificationId) {
    $frame = Read-Frame $Stream
    Assert-Result ($frame.Type -eq 'notification') 'Expected a notification signal'
    Assert-Result ($frame.Data.eventKind -eq $Kind) "Expected signal $Kind"
    Assert-Result ($frame.Data.notificationId -eq $NotificationId) 'Signal must contain the durable notification ID'
    Assert-Result ([bool]$frame.Data.eventId -and [bool]$frame.Data.occurredAt) 'Signal needs event identity/time'
    return $frame.Data
}

$a = New-TestUser
$b = New-TestUser
$c = New-TestUser
$aStream = $null
$bStream = $null
$cStream = $null
$bReconnected = $null
try {
    $aStream = Open-Stream $a
    $bStream = Open-Stream $b
    $cStream = Open-Stream $c
    foreach ($stream in @($aStream, $bStream, $cStream)) {
        Assert-Result ((Read-Frame $stream).Type -eq 'ready') 'Connection must flush ready immediately'
    }
    Call-Api 'GET' "/notifications/stream?recipientUserId=$($b.user.id)" $a $null 400 | Out-Null
    Call-Api 'GET' '/notifications/stream' $null $null 401 | Out-Null

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $trip = Call-Api 'POST' '/trips' $a @{ title = 'Realtime smoke'; startDate = '2026-12-01'; endDate = '2026-12-02'; selectedMemberIds = @($b.user.id) } 201
    $item = (Call-Api 'GET' '/notifications' $b).items[0]
    $created = Read-Signal $bStream 'CREATED' $item.id
    $watch.Stop()
    $createdLatencyMs = $watch.ElapsedMilliseconds
    Assert-Result ($item.invitationStatus -eq 'PENDING' -and $trip.memberCount -eq 1 -and $trip.tripType -eq 'PERSONAL') 'SSE must not create membership'

    # An unrelated user receives no event. Discard this stream after the bounded read.
    $unrelatedRead = $cStream.Reader.ReadLineAsync()
    Assert-Result (-not $unrelatedRead.Wait(150)) 'Notification must not leak to another user'
    Close-Stream $cStream
    $cStream = $null

    $watch.Restart()
    Call-Api 'DELETE' "/trips/$($trip.id)/invitations/$($item.invitationId)" $a | Out-Null
    $cancelled = Read-Signal $bStream 'UPDATED' $item.id
    $watch.Stop()
    $cancelLatencyMs = $watch.ElapsedMilliseconds
    $fresh = Call-Api 'GET' "/notifications/$($item.id)" $b
    Assert-Result ($fresh.invitationStatus -eq 'CANCELLED') 'Cancel signal must resolve to committed CANCELLED state'
    Call-Api 'POST' "/trip-invitations/$($item.invitationId)/accept" $b $null 409 | Out-Null
    $newInvite = Call-Api 'POST' "/trips/$($trip.id)/invitations" $a @{ inviteeUserId = $b.user.id } 201
    $newItem = @((Call-Api 'GET' '/notifications' $b).items | Where-Object invitationId -eq $newInvite.invitationId)[0]
    $reinvited = Read-Signal $bStream 'CREATED' $newItem.id
    Assert-Result ($item.id -ne $newItem.id -and $item.invitationId -ne $newItem.invitationId -and $created.eventId -ne $reinvited.eventId) 'Re-invite must have distinct notification/invitation/event identity'

    $watch.Restart()
    $accepted = Call-Api 'POST' "/trip-invitations/$($newInvite.invitationId)/accept" $b
    Read-Signal $bStream 'UPDATED' $newItem.id | Out-Null
    $aItem = (Call-Api 'GET' '/notifications' $a).items[0]
    Read-Signal $aStream 'CREATED' $aItem.id | Out-Null
    $watch.Stop()
    $acceptLatencyMs = $watch.ElapsedMilliseconds
    Assert-Result ($accepted.tripType -eq 'GROUP' -and $accepted.memberCount -eq 2 -and $null -ne $accepted.linkedConversationId) 'Accept must preserve the real GROUP/chat transaction'

    Close-Stream $bStream
    $bStream = $null
    $missed = Call-Api 'POST' '/trips' $a @{ title = 'Disconnected reconciliation'; startDate = '2026-12-01'; endDate = '2026-12-02'; selectedMemberIds = @($b.user.id) } 201
    $bReconnected = Open-Stream $b
    Assert-Result ((Read-Frame $bReconnected).Type -eq 'ready') 'Reconnect should establish a new authenticated stream'
    $bInbox = Call-Api 'GET' '/notifications' $b
    Assert-Result (@($bInbox.items | Where-Object tripId -eq $missed.id).Count -eq 1) 'REST must recover a missed notification without replay'
    Call-Api 'POST' '/auth/logout' $b $null 204 | Out-Null
    Call-Api 'GET' '/notifications/stream' $b $null 401 | Out-Null

    [ordered]@{
        result = 'PASS'; transport = 'SSE'; authenticatedIsolation = 'PASS'; newInvitation = 'PASS'
        cancelUpdatesSameNotification = 'PASS'; acceptUpdatesRecipientAndInviter = 'PASS'; reinviteDistinct = 'PASS'
        disconnectedActionPersists = 'PASS'; reconnectRestReconciliation = 'PASS'; revokedSessionRejected = 'PASS'
        observedCreateMs = $createdLatencyMs; observedCancelMs = $cancelLatencyMs; observedAcceptMs = $acceptLatencyMs
        measurement = 'Local request-to-received signal, includes REST verification; not a product SLA'
    } | ConvertTo-Json
} finally {
    Close-Stream $aStream
    Close-Stream $bStream
    Close-Stream $cStream
    Close-Stream $bReconnected
}
