param(
    [ValidatePattern('^FO-\d{8}-\d{6}-[a-f0-9]{6}$')]
    [string]$RunId = "FO-20261117-151645-24e67c",
    [ValidateNotNullOrEmpty()]
    [string]$OldPrimary = "lab13-isolated-primary-1",
    [ValidateNotNullOrEmpty()]
    [string]$NewPrimary = "lab13-isolated-replica-1"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$newPrimary = $NewPrimary
$oldPrimary = $OldPrimary
$csvPath = ".\results\failover-$RunId.csv"

$transactions = @(Import-Csv -LiteralPath $csvPath)

if ($transactions.Count -eq 0) {
    throw "Workload CSV is empty."
}

if (@($transactions | Where-Object run_id -ne $RunId).Count -gt 0) {
    throw "CSV contains an unexpected run_id."
}

$duplicates = @(
    $transactions |
        Group-Object order_id |
        Where-Object Count -gt 1
)

if ($duplicates.Count -gt 0) {
    throw "Duplicate order IDs in workload CSV."
}

# Verify that the destination is now a primary.
$role = & docker exec $newPrimary `
    psql -X -w -A -t -U postgres -d ha_lab `
    -v ON_ERROR_STOP=1 -c "SELECT pg_is_in_recovery();"

if ($LASTEXITCODE -ne 0 -or "$role".Trim() -ne "f") {
    throw "Destination is not confirmed as primary."
}

# Read only orders belonging to this exact test run.
$sql = "SELECT order_id FROM public.orders WHERE order_id LIKE '$RunId-%' ORDER BY order_id;"

$rawIds = & docker exec $newPrimary `
    psql -X -w -A -t -U postgres -d ha_lab `
    -v ON_ERROR_STOP=1 -c $sql

if ($LASTEXITCODE -ne 0) {
    throw "Database query failed. No comparison was produced."
}

$dbIds = @(
    $rawIds |
        ForEach-Object { "$_".Trim() } |
        Where-Object { $_ -ne "" }
)

$dbIds | Set-Content ".\results\db-orders-$RunId.txt" -Encoding UTF8

$details = @(
    foreach ($tx in $transactions) {
        [PSCustomObject]@{
            run_id                 = $RunId
            order_id               = $tx.order_id
            original_target        = $tx.target
            write_status           = $tx.status
            ack_utc                = $tx.ack_utc
            present_on_new_primary = ($tx.order_id -in $dbIds)
        }
    }
)

$acked = @($details | Where-Object write_status -eq "ACK")

$ackedOld = @(
    $acked | Where-Object original_target -eq $oldPrimary
)

$ackedNew = @(
    $acked | Where-Object original_target -eq $newPrimary
)

$missingAck = @(
    $acked | Where-Object { -not $_.present_on_new_primary }
)

$missingOldAck = @(
    $ackedOld | Where-Object { -not $_.present_on_new_primary }
)

$unconfirmed = @(
    $details | Where-Object write_status -eq "UNCONFIRMED"
)

$unconfirmedPresent = @(
    $unconfirmed | Where-Object present_on_new_primary
)

$summary = [PSCustomObject]@{
    run_id                     = $RunId
    checked_utc                = [DateTime]::UtcNow.ToString("o")
    attempted_total            = $transactions.Count
    ack_old_primary            = $ackedOld.Count
    ack_new_primary            = $ackedNew.Count
    ack_total                  = $acked.Count
    ack_present                = $acked.Count - $missingAck.Count
    ack_missing                = $missingAck.Count
    old_primary_ack_missing    = $missingOldAck.Count
    unconfirmed_total          = $unconfirmed.Count
    unconfirmed_present        = $unconfirmedPresent.Count
    unconfirmed_absent         = $unconfirmed.Count - $unconfirmedPresent.Count
    database_rows_for_this_run = $dbIds.Count
}

$details | Export-Csv ".\results\comparison-details-$RunId.csv" `
    -NoTypeInformation -Encoding UTF8

$summary | Export-Csv ".\results\comparison-summary-$RunId.csv" `
    -NoTypeInformation -Encoding UTF8

$summary | Format-List

Write-Host "UNCONFIRMED TRANSACTIONS:"
$unconfirmed |
    Select-Object order_id, write_status, present_on_new_primary |
    Format-Table -AutoSize

if ($missingAck.Count -gt 0) {
    Write-Host "ACKNOWLEDGED TRANSACTIONS MISSING:" -ForegroundColor Yellow
    $missingAck |
        Select-Object order_id, original_target |
        Format-Table -AutoSize
}

Write-Host "DONE. Comparison files saved in results."
