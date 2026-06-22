<#
.SYNOPSIS
    IPA Manager PC Server - serves all IPAs from your PC to your iPhone
.DESCRIPTION
    Run this on your PC to automatically serve all .ipa files to your iPhone app.
    Your iPhone app will detect this server and download all IPAs automatically.
#>

$port = 8080
$ipasDir = "C:\Users\s\Downloads"  # Change this to scan more folders
$extraDirs = @(
    "C:\Users\s\Desktop",
    "C:\Users\s\Downloads\Telegram Desktop"
)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$port/")
$listener.Start()
Write-Host "?? IPA Server running on http://$((Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like '*Wi-Fi*' -or $_.InterfaceAlias -like '*Ethernet*' } | Select-Object -First 1).IPAddress):$port"
Write-Host "Press Ctrl+C to stop"

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $req = $context.Request
    $resp = $context.Response

    if ($req.RawUrl -eq "/api/list") {
        $ipas = @()
        $dirs = @($ipasDir) + $extraDirs
        foreach ($dir in $dirs) {
            if (Test-Path $dir) {
                Get-ChildItem $dir -Filter "*.ipa" -ErrorAction SilentlyContinue | ForEach-Object {
                    $ipas += @{
                        name = $_.Name
                        size = $_.Length
                        path = "/download/$($_.Name)"
                    }
                }
            }
        }
        $json = $ipas | ConvertTo-Json
        $buffer = [Text.Encoding]::UTF8.GetBytes($json)
        $resp.ContentType = "application/json"
        $resp.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    elseif ($req.RawUrl -like "/download/*") {
        $fileName = [System.Web.HttpUtility]::UrlDecode($req.RawUrl.Substring(10))
        $fullPath = $null
        $dirs = @($ipasDir) + $extraDirs
        foreach ($dir in $dirs) {
            $test = Join-Path $dir $fileName
            if (Test-Path $test) { $fullPath = $test; break }
        }
        if ($fullPath) {
            $buffer = [IO.File]::ReadAllBytes($fullPath)
            $resp.ContentType = "application/octet-stream"
            $resp.Headers.Add("Content-Disposition", "attachment; filename=`"$fileName`"")
            $resp.OutputStream.Write($buffer, 0, $buffer.Length)
        } else {
            $resp.StatusCode = 404
        }
    }
    else {
        [byte[]]$buffer = [Text.Encoding]::UTF8.GetBytes("IPA Server running")
        $resp.ContentType = "text/plain"
        $resp.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    $resp.Close()
}
