$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

$workload = @(Import-Csv ".\results\workload-LOAD-20261117-141855.csv")
$lagRows = @(Import-Csv ".\results\replication-lag-20261117-141920.csv")

$startUtc = [DateTimeOffset]::Parse($workload[0].started_utc)
$endUtc = [DateTimeOffset]::Parse($workload[-1].read_utc)
$culture = [System.Globalization.CultureInfo]::InvariantCulture

$points = @(
    foreach ($row in $lagRows) {
        # CSV cua lan do nay ghi THH24 thay vi T14.
        $time = [DateTimeOffset]::Parse(
            $row.sampled_utc.Replace("THH24:", "T14:")
        )
        if ($time -ge $startUtc -and
            $time -le $endUtc -and
            -not [string]::IsNullOrWhiteSpace($row.replay_lag_ms)) {
            [PSCustomObject]@{
                time = $time
                lag = [double]::Parse($row.replay_lag_ms, $culture)
            }
        }
    }
)

if ($points.Count -ne 258) {
    throw "Expected 258 lag samples during workload; found $($points.Count)."
}

$width = 1000
$height = 460
$left = 85
$right = 955
$top = 75
$bottom = 375
$yMax = 12.0

$xy = @(
    for ($i = 0; $i -lt $points.Count; $i++) {
        $x = $left + ($right - $left) * $i / ($points.Count - 1)
        $y = $bottom - ($bottom - $top) * $points[$i].lag / $yMax
        "{0},{1}" -f `
            $x.ToString("0.0", $culture), `
            $y.ToString("0.0", $culture)
    }
) -join " "

$meanY = ($bottom - ($bottom - $top) * 1.326 / $yMax).
    ToString("0.0", $culture)
$p95Y = ($bottom - ($bottom - $top) * 1.797 / $yMax).
    ToString("0.0", $culture)

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">
<rect width="100%" height="100%" fill="white"/>
<text x="85" y="35" font-family="Arial" font-size="22" font-weight="bold">Replication lag khi co tai</text>
<text x="85" y="56" font-family="Arial" font-size="13" fill="#555">LOAD-20261117-141855 | 258 mau | 14:18:55–14:28:54 UTC</text>
<line x1="$left" y1="$top" x2="$left" y2="$bottom" stroke="#333"/>
<line x1="$left" y1="$bottom" x2="$right" y2="$bottom" stroke="#333"/>
<line x1="$left" y1="225" x2="$right" y2="225" stroke="#ddd"/>
<line x1="$left" y1="$top" x2="$right" y2="$top" stroke="#ddd"/>
<text x="35" y="380" font-family="Arial" font-size="13">0</text>
<text x="35" y="230" font-family="Arial" font-size="13">6</text>
<text x="27" y="80" font-family="Arial" font-size="13">12</text>
<text x="27" y="60" font-family="Arial" font-size="13">ms</text>
<text x="85" y="400" font-family="Arial" font-size="13">14:18:55</text>
<text x="880" y="400" font-family="Arial" font-size="13">14:28:54 UTC</text>
<line x1="$left" y1="$meanY" x2="$right" y2="$meanY" stroke="#e67e22" stroke-dasharray="6 5"/>
<line x1="$left" y1="$p95Y" x2="$right" y2="$p95Y" stroke="#8e44ad" stroke-dasharray="6 5"/>
<polyline points="$xy" fill="none" stroke="#147d64" stroke-width="2"/>
<text x="85" y="430" font-family="Arial" font-size="13" fill="#147d64">Lag theo mau</text>
<text x="270" y="430" font-family="Arial" font-size="13" fill="#e67e22">Trung binh: 1.326 ms</text>
<text x="500" y="430" font-family="Arial" font-size="13" fill="#8e44ad">P95: 1.797 ms</text>
<text x="680" y="430" font-family="Arial" font-size="13">Max: 10.411 ms</text>
</svg>
"@

$outputPath = ".\results\lag-chart-LOAD-20261117-141855.svg"
Set-Content -LiteralPath $outputPath -Value $svg -Encoding UTF8
[void]([xml](Get-Content -LiteralPath $outputPath -Raw))
Write-Host "Chart created: $outputPath ($($points.Count) samples)"