# IntentShell Forensics Module
# High-level wrapper for GhostDriver and NativeOps

Import-Module "$PSScriptRoot\GhostDriver.psm1" -Force
Import-Module "$PSScriptRoot\NativeOps.psm1" -Force

function Invoke-ForensicScan {
    param(
        [string]$ProcessName
    )
    
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) {
        throw "Process '$ProcessName' not found."
    }
    
    $pid = $proc.Id
    Write-Output "Targeting PID: $pid"
    
    # 1. Get Real Path via Kernel Proxy
    $realPath = Get-GhostPath -Pid $pid
    
    # 2. Read PE Header (First 256 bytes)
    $memoryDump = Invoke-GhostRead -Pid $pid -Address 0 -Size 256
    
    # 3. Basic Heuristics
    $isSuspicious = $false
    $report = @()
    
    if ($realPath -notmatch "^C:\\Windows") {
        $report += "[INFO] Process is running from non-system path: $realPath"
    }
    
    if ($memoryDump -match "4D 5A") {
        $report += "[OK] Valid PE Header (MZ) detected."
    } else {
        $report += "[WARN] PE Header missing or obfuscated!"
        $isSuspicious = $true
    }
    
    return @{
        Process = $ProcessName
        PID = $pid
        RealPath = $realPath
        Suspicious = $isSuspicious
        Report = $report
        MemorySnippet = $memoryDump.Substring(0, 50) + "..."
    }
}

Export-ModuleMember -Function Invoke-ForensicScan
