# IntentShell Sentinel (Security Engine)
# The Watcher on the Wall - Enforces Security Policies at the Kernel Level

function Get-RiskScore {
    param(
        [string]$Command,
        [object]$Intent
    )

    $score = 0
    $reasons = @()

    # --- 1. System Integrity & Malware Heuristics (CRITICAL) ---
    
    # [NEW] Kernel Driver Policy Violation
    if ($Command -match "IOCTL_.*_WRITE" -or $Command -match "Write-KernelMemory" -or $Command -match "ZwWriteVirtualMemory") {
        $score += 100
        $reasons += "Critical: Attempt to WRITE to Kernel Memory (Strictly Prohibited)"
    }

    # [NEW] Raw Disk Access
    if ($Command -match "\\\\\.\\PhysicalDrive" -or $Command -match "\\\\\.\\C:") {
        $score += 80
        $reasons += "High: Direct Raw Disk Access detected (Potential Wiper/Rootkit behavior)"
    }

    # Shadow Copy / Backup Tampering
    if ($Command -match "vssadmin.*delete" -or $Command -match "wbadmin.*delete" -or $Command -match "bcdedit.*recoveryenabled") {
        $score += 100
        $reasons += "Critical: Attempt to tamper with system backups/recovery (Ransomware behavior)"
    }

    # Credential Theft / LSASS Access
    if ($Command -match "comsvcs\.dll" -or $Command -match "rundll32.*minidump" -or $Command -match "reg.*save.*hklm\\sam") {
        $score += 100
        $reasons += "Critical: Attempt to dump credentials (LSASS/SAM)"
    }

    # Reverse Shell / C2 Patterns
    if ($Command -match "Net\.Sockets\.TCPClient" -or $Command -match "System\.Net\.WebClient" -or $Command -match "IEX.*DownloadString") {
        $score += 80
        $reasons += "High: Potential Reverse Shell or C2 activity detected"
    }

    # Obfuscation Detection
    if ($Command -match "FromBase64String" -or $Command -match "-enc\s+[a-zA-Z0-9+/=]{20,}") {
        $score += 60
        $reasons += "High: Obfuscated command detected (Base64)"
    }

    # --- 2. Path Sensitivity Analysis ---
    $targetPath = $Intent.target
    if (-not [string]::IsNullOrWhiteSpace($targetPath)) {
        $sensitivePaths = @(
            "C:\Windows", "C:\Program Files", "C:\Program Files (x86)", "C:\Users", "C:\"
        )
        
        foreach ($path in $sensitivePaths) {
            # Normalize paths for comparison (simple string check for MVP)
            if ($targetPath -eq $path -or $targetPath.StartsWith("$path\")) {
                # Exception: User's own documents/desktop are usually fine, but root Users is not
                if ($targetPath -eq "C:\Users") {
                    $score += 50
                    $reasons += "Target is a sensitive system directory: $targetPath"
                } elseif ($targetPath.StartsWith("C:\Windows")) {
                    $score += 50
                    $reasons += "Target is a sensitive system directory: $targetPath"
                }
            }
        }
    }

    # --- 3. Destructive Command Analysis ---
    $destructiveKeywords = @("Remove-Item", "rm", "del", "erase", "Format-Volume", "Stop-Process", "kill", "Set-ItemProperty")
    
    foreach ($kw in $destructiveKeywords) {
        if ($Command -match "\b$kw\b") {
            $score += 20
            $reasons += "Command contains destructive keyword: $kw"
            
            if ($Intent.recursive) {
                $score += 20
                $reasons += "Recursive operation on destructive command"
            }
            
            if ($Intent.target -match "\*" -or ($null -eq $Intent.filters -or $Intent.filters.Count -eq 0)) {
                $score += 10
                $reasons += "Bulk operation without specific filters"
            }
            break # Count once
        }
    }

    # --- 4. Intent Specifics ---
    if ($Intent.intent_type -eq "delete_files" -and $Intent.filters) {
        # Check safe extensions
        $safeExtensions = @(".tmp", ".log", ".bak", ".cache")
        $allSafe = $true
        foreach ($f in $Intent.filters) {
            if ($f -notin $safeExtensions) { $allSafe = $false }
        }
        
        if ($allSafe) {
            $score -= 10
            $reasons += "Mitigating Factor: Only safe extensions targeted"
        }
    }

    return @{
        Score = $score
        Reasons = $reasons
    }
}

function Measure-Risk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Intent,
        
        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    $assessment = Get-RiskScore -Command $Command -Intent $Intent
    $score = $assessment.Score
    $finalLevel = "low"

    if ($score -ge 50) {
        $finalLevel = "high"
    } elseif ($score -ge 20) {
        $finalLevel = "medium"
    }

    # AI Override (Conservative)
    if ($Intent.risk -eq "high" -and $finalLevel -ne "high") {
        $finalLevel = "high"
        $assessment.Reasons += "AI Model originally flagged this as HIGH risk"
    }

    return @{
        level = $finalLevel
        score = $score
        reasons = $assessment.Reasons
    }
}

Export-ModuleMember -Function Measure-Risk
