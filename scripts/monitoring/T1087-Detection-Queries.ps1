# T1087 Account Discovery Detection Queries
# Author: Greg Lewis
# Date: 2025-12-20
# Platform: Windows 11 + Sysmon

param(
    [string]$AttackerIP = "192.168.8.95",
    [int]$Hours = 2
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "T1087 Account Discovery Detection" -ForegroundColor Cyan
Write-Host "Attacker IP: $AttackerIP" -ForegroundColor Yellow
Write-Host "Time Range: Last $Hours hours" -ForegroundColor Yellow
Write-Host "=========================================`n" -ForegroundColor Cyan

$StartTime = (Get-Date).AddHours(-$Hours)

# Query 1: Sysmon Network Connections (Limited for this technique)
Write-Host "[1] Sysmon Network Connections (Event ID 3)" -ForegroundColor Green
Write-Host "Note: Event ID 3 primarily logs outbound connections`n" -ForegroundColor Yellow

$SysmonConnections = Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 1000 -ErrorAction SilentlyContinue |
    Where-Object {$_.Id -eq 3 -and $_.TimeCreated -gt $StartTime}

if ($SysmonConnections) {
    Write-Host "Total Sysmon network events: $($SysmonConnections.Count)" -ForegroundColor White
    
    $SysmonConnections |
        Select-Object -First 10 TimeCreated, @{Name='Details';Expression={
            if ($_.Message -match 'DestinationPort: (\d+)') {
                "Port: $($matches[1])"
            }
        }} |
        Format-Table -AutoSize
} else {
    Write-Host "No Sysmon Event ID 3 found (expected for inbound enumeration)" -ForegroundColor Yellow
}

# Query 2: Windows Security - Firewall Connections (Event ID 5156)
Write-Host "`n[2] Windows Filtering Platform Connections (Event ID 5156)" -ForegroundColor Green

try {
    $FirewallEvents = Get-WinEvent -FilterHashtable @{
        LogName='Security'
        ID=5156
        StartTime=$StartTime
    } -MaxEvents 100 -ErrorAction Stop
    
    $SMBConnections = $FirewallEvents | Where-Object {
        $_.Message -match '445|139'
    }
    
    Write-Host "Total firewall events: $($FirewallEvents.Count)" -ForegroundColor White
    Write-Host "SMB-related (445/139): $($SMBConnections.Count)" -ForegroundColor White
    
    if ($SMBConnections.Count -gt 0) {
        Write-Host "`nSMB Connection Details:" -ForegroundColor Cyan
        $SMBConnections | Select-Object -First 10 TimeCreated | Format-Table -AutoSize
    }
} catch {
    Write-Host "Event ID 5156 not available or auditing not enabled" -ForegroundColor Red
    Write-Host "Enable with: auditpol /set /subcategory:`"Filtering Platform Connection`" /success:enable" -ForegroundColor Yellow
}

# Query 3: Failed Logon Attempts (Event ID 4625)
Write-Host "`n[3] Failed Logon Attempts (Event ID 4625)" -ForegroundColor Green

try {
    $FailedLogons = Get-WinEvent -FilterHashtable @{
        LogName='Security'
        ID=4625
        StartTime=$StartTime
    } -MaxEvents 50 -ErrorAction Stop |
        Where-Object {$_.Message -like "*$AttackerIP*"}
    
    if ($FailedLogons) {
        Write-Host "Failed logons from $AttackerIP : $($FailedLogons.Count)" -ForegroundColor Red
        $FailedLogons | Select-Object TimeCreated | Format-Table -AutoSize
    } else {
        Write-Host "No failed logons from $AttackerIP (anonymous enum doesn't trigger auth)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Event ID 4625 not available or auditing not enabled" -ForegroundColor Red
    Write-Host "Enable with: auditpol /set /subcategory:`"Logon`" /success:enable /failure:enable" -ForegroundColor Yellow
}

# Query 4: Successful Logons (Event ID 4624)
Write-Host "`n[4] Successful Logons (Event ID 4624)" -ForegroundColor Green

try {
    $SuccessLogons = Get-WinEvent -FilterHashtable @{
        LogName='Security'
        ID=4624
        StartTime=$StartTime
    } -MaxEvents 50 -ErrorAction Stop |
        Where-Object {$_.Message -like "*$AttackerIP*"}
    
    if ($SuccessLogons) {
        Write-Host "Successful logons from $AttackerIP : $($SuccessLogons.Count)" -ForegroundColor Green
        $SuccessLogons | Select-Object TimeCreated | Format-Table -AutoSize
    } else {
        Write-Host "No successful logons from $AttackerIP" -ForegroundColor White
    }
} catch {
    Write-Host "Event ID 4624 not available" -ForegroundColor Red
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Detection Analysis Complete" -ForegroundColor Cyan
Write-Host "=========================================`n" -ForegroundColor Cyan

# Summary
Write-Host "DETECTION SUMMARY:" -ForegroundColor Yellow
Write-Host "- Sysmon Event ID 3: Limited effectiveness (outbound only)" -ForegroundColor White
Write-Host "- Windows Security logs: Primary detection method" -ForegroundColor White
Write-Host "- Multi-layer approach required for comprehensive coverage" -ForegroundColor White