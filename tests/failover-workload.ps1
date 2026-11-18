param(
    [ValidateRange(1, 86400)]
    [int]$DurationSeconds = 600,

    [ValidateRange(100, 60000)]
    [int]$IntervalMs = 1000
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Get-Command docker -ErrorAction Stop | Out-Null
New-Item -ItemType Directory -Force -Path ".\results" | Out-Null

$targetFile = ".\results\write-target.txt"

if (-not (Test-Path -LiteralPath $targetFile)) {
    throw "Missing results/write-target.txt"
}

$allowedTargets = @(
    "lab13-isolated-primary-1",
    "lab13-isolated-replica-1"
)

$initialTarget = (Get-Content -LiteralPath $targetFile -Raw).Trim()

if ($initialTarget -notin $allowedTargets) {
    throw "Invalid target container: $initialTarget"
}

$stamp = [DateTime]::UtcNow.ToString("yyyyMMdd-HHmmss")
$suffix = [Guid]::NewGuid().ToString("N").Substring(0, 6)
$runId = "FO-$stamp-$suffix"
$csvPath = ".\results\failover-$runId.csv"

$timer = [Diagnostics.Stopwatch]::StartNew()
$sequence = 0

Write-Host "RUN: $runId"
Write-Host "CSV: $csvPath"
Write-Host "TARGET FILE: $targetFile"
Write-Host "INITIAL TARGET: $initialTarget"

while ($timer.Elapsed.TotalSeconds -lt $DurationSeconds) {
    $sequence++
    $orderId = "{0}-{1:D6}" -f $runId, $sequence
    $startedUtc = [DateTime]::UtcNow.ToString("o")
    $attemptTimer = [Diagnostics.Stopwatch]::StartNew()

    $target = ""
    $status = "CONFIG_ERROR"
    $ackUtc = ""
    $exitCode = -1
    $detail = ""

    try {
        $target = (Get-Content -LiteralPath $targetFile -Raw).Trim()

        if ($target -notin $allowedTargets) {
            throw "Invalid target container: $target"
        }

        $status = "UNCONFIRMED"
        $sql = "INSERT INTO public.orders(order_id, amount) VALUES ('$orderId', 100.00) RETURNING order_id;"
        $output = @()

        # Native-command errors must not stop the workload.
        try {
            $ErrorActionPreference = "Continue"

            $output = & docker exec `
                -e "PGCONNECT_TIMEOUT=3" `
                -e "PGOPTIONS=-c statement_timeout=3000 -c lock_timeout=2000" `
                $target `
                psql -X -w -q -A -t `
                -U postgres -d ha_lab `
                -v ON_ERROR_STOP=1 `
                -c $sql 2>&1

            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = "Stop"
        }

        $resultText = ($output | Out-String).Trim()

        if (($exitCode -eq 0) -and ($resultText -eq $orderId)) {
            $status = "ACK"
            $ackUtc = [DateTime]::UtcNow.ToString("o")
        }
        else {
            $detail = $resultText

            if ([string]::IsNullOrWhiteSpace($detail)) {
                $detail = "No successful commit confirmation"
            }
        }
    }
    catch {
        $detail = $_.Exception.Message
    }

    $attemptTimer.Stop()

    [PSCustomObject]@{
        run_id       = $runId
        sequence     = $sequence
        order_id     = $orderId
        target       = $target
        started_utc  = $startedUtc
        finished_utc = [DateTime]::UtcNow.ToString("o")
        ack_utc      = $ackUtc
        status       = $status
        elapsed_ms   = $attemptTimer.ElapsedMilliseconds
        exit_code    = $exitCode
        detail       = $detail
    } | Export-Csv -LiteralPath $csvPath -Append `
        -NoTypeInformation -Encoding UTF8

    Write-Host (
        "{0} | {1} | target={2} | {3}" -f `
        [DateTime]::UtcNow.ToString("HH:mm:ss.fff"), `
        $orderId, $target, $status
    )

    if ($status -ne "ACK") {
        Write-Host "  Detail: $detail" -ForegroundColor Yellow
    }

    Start-Sleep -Milliseconds $IntervalMs
}

Write-Host "DONE. CSV: $csvPath"