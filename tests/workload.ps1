param(
    [ValidateRange(1, 86400)]
    [int]$DurationSeconds = 600,
    [ValidateNotNullOrEmpty()]
    [string]$PrimaryContainer = "lab13-isolated-primary-1",
    [ValidateNotNullOrEmpty()]
    [string]$ReplicaContainer = "lab13-isolated-replica-1",
    [ValidateRange(0, 60000)]
    [int]$IntervalMilliseconds = 1000
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

New-Item -ItemType Directory -Force -Path ".\results" | Out-Null

$runId = "LOAD-" + [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
$csvPath = ".\results\workload-$runId.csv"
$timer = [Diagnostics.Stopwatch]::StartNew()
$sequence = 0

Write-Host "RUN: $runId"
Write-Host "CSV: $csvPath"
Write-Host "Write: $PrimaryContainer | Read: $ReplicaContainer"
Write-Host "Interval: $IntervalMilliseconds ms"

while ($timer.Elapsed.TotalSeconds -lt $DurationSeconds) {
    $sequence++
    $orderId = "{0}-{1:D6}" -f $runId, $sequence
    $startedUtc = [DateTime]::UtcNow.ToString("o")
    $writeTimer = [Diagnostics.Stopwatch]::StartNew()

    $writeSql = "INSERT INTO public.orders(order_id, amount) VALUES ('$orderId', 100.00);"

    $writeOutput = & docker exec $PrimaryContainer `
        psql -X -q -U postgres -d ha_lab `
        -v ON_ERROR_STOP=1 -c $writeSql 2>&1

    $writeExit = $LASTEXITCODE
    $writeTimer.Stop()

    $writeStatus = "UNCONFIRMED"
    $ackUtc = ""
    $writeError = ""

    if ($writeExit -eq 0) {
        $writeStatus = "ACK"
        $ackUtc = [DateTime]::UtcNow.ToString("o")
    } else {
        $writeError = ($writeOutput | Out-String).Trim()
    }

    $readSql = "SELECT count(*) FROM public.orders WHERE order_id='$orderId';"

    $readOutput = & docker exec $ReplicaContainer `
        psql -X -A -t -U postgres -d ha_lab `
        -v ON_ERROR_STOP=1 -c $readSql 2>&1

    $readExit = $LASTEXITCODE
    $readText = ($readOutput | Out-String).Trim()
    $readStatus = "ERROR"
    $replicaRows = ""
    $readError = ""

    if ($readExit -eq 0) {
        $readStatus = "OK"
        $replicaRows = $readText
    } else {
        $readError = $readText
    }

    [PSCustomObject]@{
        run_id        = $runId
        order_id      = $orderId
        started_utc   = $startedUtc
        ack_utc       = $ackUtc
        write_status  = $writeStatus
        write_ms      = $writeTimer.ElapsedMilliseconds
        read_utc      = [DateTime]::UtcNow.ToString("o")
        read_status   = $readStatus
        replica_rows  = $replicaRows
        write_error   = $writeError
        read_error    = $readError
    } | Export-Csv -LiteralPath $csvPath -Append `
        -NoTypeInformation -Encoding UTF8

    Write-Host (
        "{0} | {1} | write={2} | read={3} | replica_rows={4}" -f `
        [DateTime]::UtcNow.ToString("HH:mm:ss"), `
        $orderId, $writeStatus, $readStatus, $replicaRows
    )

    Start-Sleep -Milliseconds $IntervalMilliseconds
}

Write-Host "DONE. CSV: $csvPath"
