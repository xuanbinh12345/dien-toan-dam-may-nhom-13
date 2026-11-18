param(
    [string]$ManifestPath = "results/repeat-lag-20261118/manifest.csv",
    [string]$OutputPath = "results/repeat-lag-20261118/summary.csv"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$manifest = @(Import-Csv -LiteralPath $ManifestPath)
if ($manifest.Count -eq 0) { throw "Manifest has no runs: $ManifestPath" }

$summary = foreach ($run in $manifest) {
    $workload = @(Import-Csv -LiteralPath $run.workload_csv)
    $lag = @(Import-Csv -LiteralPath $run.lag_csv)
    if ($workload.Count -eq 0 -or $lag.Count -eq 0) {
        throw "Empty CSV in run $($run.repeat) at interval $($run.level_interval_ms)"
    }

    $start = [DateTimeOffset]::Parse($workload[0].started_utc, $culture)
    $end = [DateTimeOffset]::Parse($workload[-1].read_utc, $culture)
    $seconds = ($end - $start).TotalSeconds
    if ($seconds -le 0) { throw "Invalid workload window: $($run.workload_csv)" }

    $during = @(
        foreach ($sample in $lag) {
            $stamp = $sample.sampled_utc
            if ($stamp.Contains("THH24:")) {
                if ([string]::IsNullOrWhiteSpace($run.timestamp_hour_fix)) {
                    throw "Timestamp needs hour correction: $($run.lag_csv)"
                }
                $stamp = $stamp.Replace("THH24:", "T$($run.timestamp_hour_fix):")
            }
            $time = [DateTimeOffset]::Parse($stamp, $culture)
            if ($time -ge $start -and $time -le $end) { $sample }
        }
    )
    if ($during.Count -eq 0) { throw "No lag samples during load: $($run.lag_csv)" }

    $lagValues = @(
        $during |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.replay_lag_ms) } |
            ForEach-Object { [double]::Parse($_.replay_lag_ms, $culture) } |
            Sort-Object
    )
    if ($lagValues.Count -eq 0) { throw "No numeric lag samples: $($run.lag_csv)" }
    $lagStats = $lagValues | Measure-Object -Average -Maximum
    $p95Index = [math]::Ceiling(0.95 * $lagValues.Count) - 1

    $gapValues = @(
        $during |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.replay_gap_bytes) } |
            ForEach-Object { [double]::Parse($_.replay_gap_bytes, $culture) }
    )
    $maxGap = if ($gapValues.Count) { ($gapValues | Measure-Object -Maximum).Maximum } else { "" }

    [PSCustomObject]@{
        level_interval_ms       = $run.level_interval_ms
        repeat                  = $run.repeat
        run_id                  = $workload[0].run_id
        workload_csv            = $run.workload_csv
        lag_csv                 = $run.lag_csv
        load_start_utc          = $start.ToUniversalTime().ToString("o")
        load_end_utc            = $end.ToUniversalTime().ToString("o")
        load_seconds            = $seconds.ToString("0.00", $culture)
        writes                  = $workload.Count
        ack                     = @($workload | Where-Object { $_.write_status -eq "ACK" }).Count
        read_one                = @($workload | Where-Object { $_.read_status -eq "OK" -and $_.replica_rows -eq "1" }).Count
        writes_per_second       = ($workload.Count / $seconds).ToString("0.000", $culture)
        raw_lag_samples         = $lag.Count
        lag_samples_during_load = $during.Count
        null_lag_during_load    = $during.Count - $lagValues.Count
        mean_lag_ms             = $lagStats.Average.ToString("0.000", $culture)
        p95_lag_ms              = $lagValues[$p95Index].ToString("0.000", $culture)
        max_lag_ms              = $lagStats.Maximum.ToString("0.000", $culture)
        max_replay_gap_bytes    = $maxGap
        streaming_async_samples = @($during | Where-Object { $_.state -eq "streaming" -and $_.sync_state -eq "async" }).Count
        timestamp_hour_fix      = $run.timestamp_hour_fix
    }
}

$summary | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
Write-Host "Summary: $OutputPath ($($summary.Count) runs)"
