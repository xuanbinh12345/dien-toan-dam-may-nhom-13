param(
    [int]$DurationSeconds = 600
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

New-Item -ItemType Directory -Force -Path ".\results" | Out-Null

$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
$csvPath = ".\results\replication-lag-$stamp.csv"
$timer = [Diagnostics.Stopwatch]::StartNew()

$sql = @"
SELECT
    to_char(
        clock_timestamp() AT TIME ZONE 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
    ) AS sampled_utc,
    r.application_name,
    r.state,
    r.sync_state,
    pg_wal_lsn_diff(
        pg_current_wal_lsn(), r.replay_lsn
    ) AS replay_gap_bytes,
    round(
        extract(epoch FROM r.replay_lag) * 1000, 3
    ) AS replay_lag_ms
FROM (SELECT 1) AS sample
LEFT JOIN pg_stat_replication AS r ON true;
"@

Write-Host "CSV: $csvPath"

while ($timer.Elapsed.TotalSeconds -lt $DurationSeconds) {
    $output = & docker exec lab13-isolated-primary-1 `
        psql -X --csv -U postgres -d ha_lab `
        -v ON_ERROR_STOP=1 -c $sql 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw ("Replication query failed: " + ($output | Out-String))
    }

    $rows = @(($output | Out-String) | ConvertFrom-Csv)

    foreach ($row in $rows) {
        $row | Export-Csv -LiteralPath $csvPath -Append `
            -NoTypeInformation -Encoding UTF8

        $stateText = $row.state
        if ([string]::IsNullOrWhiteSpace($stateText)) {
            $stateText = "NO_REPLICA"
        }

        $lagText = $row.replay_lag_ms
        if ([string]::IsNullOrWhiteSpace($lagText)) {
            $lagText = "NULL"
        }

        Write-Host (
            "{0} | {1}/{2} | gap_bytes={3} | replay_lag_ms={4}" -f `
            $row.sampled_utc, $stateText, $row.sync_state, `
            $row.replay_gap_bytes, $lagText
        )
    }

    Start-Sleep -Seconds 2
}

Write-Host "DONE. CSV: $csvPath"