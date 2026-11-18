param(
    [switch]$ExecuteFailover
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
Get-Command docker -ErrorAction Stop | Out-Null

$oldPrimary = "lab13-repeat-primary-1"
$newPrimary = "lab13-repeat-replica-1"
$manifestPath = "results/repeat-lag-20261118/manifest.csv"
$expectedCount = 1132
$targetSeconds = 30

function Query-Scalar {
    param([string]$Container, [string]$Sql)
    $output = & docker exec $Container psql -X -w -A -t -q `
        -v ON_ERROR_STOP=1 -U postgres -d ha_lab -c $Sql 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Query failed on ${Container}: $($output | Out-String)"
    }
    return ($output | Out-String).Trim()
}

function Get-LoadIds {
    param([string]$Container)
    $sql = "SELECT order_id FROM public.orders WHERE order_id LIKE 'LOAD-20261118-%' ORDER BY order_id;"
    $output = Query-Scalar -Container $Container -Sql $sql
    return @($output -split "`r?`n" | Where-Object { $_ -ne "" })
}

function Save-Event {
    param([string]$Name)
    $utc = [DateTimeOffset]::UtcNow.ToString("o")
    [PSCustomObject]@{ run_id = $runId; event = $Name; utc = $utc } |
        Export-Csv -LiteralPath $eventsPath -Append -NoTypeInformation -Encoding UTF8
    Write-Host "$utc | $Name"
    return $utc
}

# Read-only checks run even when -ExecuteFailover is omitted.
$oldRole = Query-Scalar $oldPrimary "SELECT pg_is_in_recovery();"
$newRole = Query-Scalar $newPrimary "SELECT pg_is_in_recovery();"
if ($oldRole -ne "f" -or $newRole -ne "t") {
    throw "Unexpected roles. Old primary=$oldRole, replica=$newRole. Do not fail over."
}
$streaming = Query-Scalar $oldPrimary "SELECT count(*) FROM pg_stat_replication WHERE state='streaming' AND sync_state='async';"
if ([int]$streaming -lt 1) { throw "Replica is not streaming/async. Do not fail over." }

$manifest = @(Import-Csv -LiteralPath $manifestPath)
if ($manifest.Count -ne 6) { throw "Expected six workload runs in manifest." }
$ackIds = @(
    foreach ($run in $manifest) {
        Import-Csv -LiteralPath $run.workload_csv |
            Where-Object { $_.write_status -eq "ACK" } |
            ForEach-Object { $_.order_id }
    }
)
$expectedIds = @($ackIds | Sort-Object -Unique)
if ($ackIds.Count -ne $expectedCount -or $expectedIds.Count -ne $expectedCount) {
    throw "Expected $expectedCount unique ACK IDs; found $($ackIds.Count) ACK rows and $($expectedIds.Count) unique IDs."
}

$primaryIds = @(Get-LoadIds $oldPrimary)
$replicaIds = @(Get-LoadIds $newPrimary)
$missingPrimary = @($expectedIds | Where-Object { $_ -notin $primaryIds })
$missingReplica = @($expectedIds | Where-Object { $_ -notin $replicaIds })
if ($primaryIds.Count -ne $expectedCount -or $replicaIds.Count -ne $expectedCount -or
    $missingPrimary.Count -ne 0 -or $missingReplica.Count -ne 0) {
    throw "ACK ID check failed before failover: primary=$($primaryIds.Count), replica=$($replicaIds.Count), missing primary=$($missingPrimary.Count), missing replica=$($missingReplica.Count)."
}

Write-Host "PREFLIGHT OK: primary=$oldPrimary; replica=$newPrimary; streaming/async=$streaming"
Write-Host "ACK IDs present on both nodes: $expectedCount/$expectedCount"
Write-Host "Lab target: no missing ACK IDs; stop request to successful write AND read <= $targetSeconds seconds."

if (-not $ExecuteFailover) {
    Write-Host "READ-ONLY PREFLIGHT COMPLETE. No container was stopped or promoted."
    return
}

$stamp = [DateTimeOffset]::UtcNow.ToString("yyyyMMdd-HHmmss")
$suffix = [Guid]::NewGuid().ToString("N").Substring(0, 6)
$runId = "REC-$stamp-$suffix"
$resultDir = "results/recovery-$runId"
New-Item -ItemType Directory -Path $resultDir -ErrorAction Stop | Out-Null
$eventsPath = Join-Path $resultDir "events.csv"

Write-Host "RUN: $runId"
Write-Host "RESULTS: $resultDir"
$stopRequestedUtc = Save-Event "stop_requested"
& docker stop --timeout 30 $oldPrimary | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Stop failed; do not promote. Inspect container state." }
$running = (& docker inspect --format '{{.State.Running}}' $oldPrimary).Trim()
if ($LASTEXITCODE -ne 0 -or $running -ne "false") {
    throw "Old primary is not confirmed stopped; do not promote."
}
$null = Save-Event "primary_stopped"

$null = Save-Event "promotion_requested"
$promoted = Query-Scalar $newPrimary "SELECT pg_promote(true, 60);"
if ($promoted -ne "t") { throw "Promotion was not confirmed. Keep old primary stopped." }
$null = Save-Event "promotion_confirmed"

$orderId = "$runId-POST-001"
$writeSql = "INSERT INTO public.orders(order_id, amount) VALUES ('$orderId', 999.99) RETURNING order_id;"
$writeResult = Query-Scalar $newPrimary $writeSql
if ($writeResult -ne $orderId) { throw "Post-failover write was not confirmed. Keep old primary stopped." }
$writeConfirmedUtc = Save-Event "write_confirmed"

$readSql = "SELECT count(*) FROM public.orders WHERE order_id='$orderId' AND amount=999.99;"
$readResult = Query-Scalar $newPrimary $readSql
if ($readResult -ne "1") { throw "Post-failover read failed. Keep old primary stopped." }
$readConfirmedUtc = Save-Event "read_confirmed"

$afterIds = @(Get-LoadIds $newPrimary)
$missingAck = @($expectedIds | Where-Object { $_ -notin $afterIds })
$rtoSeconds = ([DateTimeOffset]::Parse($readConfirmedUtc) -
    [DateTimeOffset]::Parse($stopRequestedUtc)).TotalSeconds

$summary = [PSCustomObject]@{
    run_id                 = $runId
    old_primary            = $oldPrimary
    promoted_primary       = $newPrimary
    expected_ack_ids       = $expectedCount
    ack_ids_present        = $expectedCount - $missingAck.Count
    ack_ids_missing        = $missingAck.Count
    post_failover_order_id = $orderId
    write_confirmed_utc    = $writeConfirmedUtc
    read_confirmed_utc     = $readConfirmedUtc
    observed_rto_seconds   = [math]::Round($rtoSeconds, 3)
    target_rto_seconds     = $targetSeconds
    target_rto_met         = ($rtoSeconds -le $targetSeconds)
}
$summary | Export-Csv -LiteralPath (Join-Path $resultDir "summary.csv") `
    -NoTypeInformation -Encoding UTF8
Set-Content -LiteralPath (Join-Path $resultDir "missing-ack-ids.txt") `
    -Value $missingAck -Encoding UTF8
$summary | Format-List
Write-Host "DONE. Keep $oldPrimary stopped. Results: $resultDir"
