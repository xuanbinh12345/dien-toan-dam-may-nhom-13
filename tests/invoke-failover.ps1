$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$oldPrimary = "lab13-isolated-primary-1"
$newPrimary = "lab13-isolated-replica-1"

# Check roles before making changes.
$oldRole = & docker exec $oldPrimary `
    psql -X -w -A -t -U postgres -d ha_lab `
    -v ON_ERROR_STOP=1 -c "SELECT pg_is_in_recovery();"

if ($LASTEXITCODE -ne 0 -or "$oldRole".Trim() -ne "f") {
    throw "Old primary is not ready. Stop and check."
}

$newRole = & docker exec $newPrimary `
    psql -X -w -A -t -U postgres -d ha_lab `
    -v ON_ERROR_STOP=1 -c "SELECT pg_is_in_recovery();"

if ($LASTEXITCODE -ne 0 -or "$newRole".Trim() -ne "t") {
    throw "Replica is not in recovery. Stop and check."
}

$target = (Get-Content .\results\write-target.txt -Raw).Trim()
if ($target -ne $oldPrimary) {
    throw "write-target.txt must point to the old primary."
}

# Bind this operation to the currently running workload.
$runFile = Get-ChildItem .\results\failover-FO-*.csv |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($null -eq $runFile) {
    throw "No workload CSV found."
}

$rows = @(Import-Csv -LiteralPath $runFile.FullName)

$lastAck = $rows |
    Where-Object {
        $_.status -eq "ACK" -and $_.target -eq $oldPrimary
    } |
    Select-Object -Last 1

if ($null -eq $lastAck) {
    throw "No successful write to the old primary."
}

$age = (
    [DateTimeOffset]::UtcNow -
    [DateTimeOffset]::Parse($lastAck.ack_utc)
).TotalSeconds

if ($age -lt 0 -or $age -gt 15) {
    throw "No recent ACK. Start the workload in terminal A first."
}

$runId = $lastAck.run_id
$eventFile = ".\results\events-$runId.csv"

if (Test-Path -LiteralPath $eventFile) {
    throw "Events already exist for this run. Do not repeat."
}

function Save-Event {
    param([string]$EventName)

    $utc = [DateTime]::UtcNow.ToString("o")

    [PSCustomObject]@{
        run_id = $runId
        event   = $EventName
        utc     = $utc
    } | Export-Csv -LiteralPath $eventFile -Append `
        -NoTypeInformation -Encoding UTF8

    Write-Host "$utc | $EventName"
}

Write-Host "WORKLOAD: $($runFile.Name)"
Write-Host "EVENTS: $eventFile"

Save-Event "stop_requested"

& docker stop --timeout 30 $oldPrimary
if ($LASTEXITCODE -ne 0) {
    throw "Stopping primary failed. Do not promote."
}

$running = & docker inspect --format '{{.State.Running}}' $oldPrimary
if ($LASTEXITCODE -ne 0 -or "$running".Trim() -ne "false") {
    throw "Old primary is not confirmed stopped. Do not promote."
}

Save-Event "primary_stopped"
Save-Event "promotion_requested"

$promoted = & docker exec $newPrimary `
    psql -X -w -A -t -U postgres -d ha_lab `
    -v ON_ERROR_STOP=1 -c "SELECT pg_promote(true, 60);"

if ($LASTEXITCODE -ne 0 -or "$promoted".Trim() -ne "t") {
    throw "Promotion not confirmed. Check before continuing."
}

Save-Event "promotion_confirmed"

Set-Content -LiteralPath .\results\write-target.txt `
    -Value $newPrimary -Encoding ASCII

Save-Event "write_target_changed"

Write-Host "DONE. Watch terminal A for ACK on $newPrimary."
Write-Host "Keep the old primary stopped."