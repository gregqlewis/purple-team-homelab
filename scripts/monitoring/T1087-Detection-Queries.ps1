# T1087 Account Discovery Detection Queries
# Author: Greg Lewis
# Date: 2025-12-20

Write-Host "=== T1087 Account Discovery Detection ===" -ForegroundColor Cyan
Write-Host "Analyzing Sysmon logs for account enumeration indicators`n" -ForegroundColor Yellow

# Query 1: SMB connections from external sources
Write-Host "[1] SMB Connections (Port 445) from External IPs" -ForegroundColor Green
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 1000 |
    Where-Object {$_.Id -eq 3 -and $_.Message -match "DestinationPort: 445"} |
    Select-Object TimeCreated, @{Name='SourceIP';Expression={
        if ($_.Message -match 'SourceIp: ([\d.]+)') { $matches[1] }
    }}, @{Name='DestinationIP';Expression={
        if ($_.Message -match 'DestinationIp: ([\d.]+)') { $matches[1] }
    }} |
    Group-Object SourceIP |
    Select-Object Count, Name |
    Sort-Object Count -Descending |
    Format-Table -AutoSize

# Query 2: Local net.exe user enumeration
Write-Host "`n[2] Local Account Enumeration (net.exe)" -ForegroundColor Green
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 1000 |
    Where-Object {$_.Id -eq 1 -and $_.Message -match 'net\.exe.*user'} |
    Select-Object TimeCreated, @{Name='User';Expression={
        if ($_.Message -match 'User: (.+?)\r?\n') { $matches[1] }
    }}, @{Name='CommandLine';Expression={
        if ($_.Message -match 'CommandLine: (.+?)\r?\n') { $matches[1] }
    }} |
    Format-Table -AutoSize

# Query 3: PowerShell-based enumeration
Write-Host "`n[3] PowerShell User Enumeration" -ForegroundColor Green
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 1000 |
    Where-Object {$_.Id -eq 1 -and $_.Message -match 'Get-LocalUser|Get-ADUser|Get-WmiObject.*Win32_UserAccount'} |
    Select-Object TimeCreated, @{Name='CommandLine';Expression={
        if ($_.Message -match 'CommandLine: (.+?)\r?\n') { 
            $matches[1].Substring(0, [Math]::Min(100, $matches[1].Length))
        }
    }} |
    Format-Table -Wrap

# Query 4: Timeline of suspicious activity
Write-Host "`n[4] Timeline of Enumeration Activity" -ForegroundColor Green
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 500 |
    Where-Object {
        ($_.Id -eq 3 -and $_.Message -match "DestinationPort: 445") -or
        ($_.Id -eq 1 -and $_.Message -match 'net\.exe.*user|Get-LocalUser')
    } |
    Select-Object TimeCreated, Id, @{Name='EventType';Expression={
        switch ($_.Id) {
            1 {'Process Creation'}
            3 {'Network Connection'}
            default {"Event $($_.Id)"}
        }
    }} |
    Sort-Object TimeCreated -Descending |
    Format-Table -AutoSize

Write-Host "`n[*] Detection analysis complete!" -ForegroundColor Cyan