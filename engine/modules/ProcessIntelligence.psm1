
using module .\SystemCore.psm1

# IntentShell Process Intelligence Module
# Advanced Process Analysis & Heuristics
# Integrated with SystemCore

class ProcessIntelligenceModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    ProcessIntelligenceModule() {
        $this.Name = "ProcessIntelligence"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['Process'] = 'Read'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        return [ModuleResult]::new($false, "ProcessIntelligence: Library only (No Action defined)")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([ProcessIntelligenceModule]::new())
}

function Get-ProcessTree {
    <#
    .SYNOPSIS
    Analyzes process parent-child relationships.
    #>
    [CmdletBinding()]
    param(
        [string]$ProcessName
    )
    
    $procs = if ($ProcessName) { Get-Process -Name $ProcessName -ErrorAction SilentlyContinue } else { Get-Process }
    
    foreach ($p in $procs) {
        try {
            # Use CIM/WMI to get Parent Process ID
            $cimProc = Get-CimInstance Win32_Process -Filter "ProcessId = $($p.Id)"
            $parent = Get-Process -Id $cimProc.ParentProcessId -ErrorAction SilentlyContinue
            
            [PSCustomObject]@{
                Id = $p.Id
                Name = $p.Name
                Path = $p.Path
                ParentId = $cimProc.ParentProcessId
                ParentName = if ($parent) { $parent.Name } else { "Unknown/Terminated" }
                CommandLine = $cimProc.CommandLine
            }
        } catch {
            continue
        }
    }
}

function Get-SuspiciousProcesses {
    <#
    .SYNOPSIS
    Heuristic analysis for suspicious processes.
    #>
    [CmdletBinding()]
    param()
    
    $suspicious = @()
    $procs = Get-Process
    
    foreach ($p in $procs) {
        $score = 0
        $reasons = @()
        
        # Check 1: Running from Temp
        if ($p.Path -match "AppData\\Local\\Temp") {
            $score += 50
            $reasons += "Running from Temp"
        }
        
        # Check 2: No Description (Often malware)
        if ([string]::IsNullOrWhiteSpace($p.Description)) {
            $score += 20
            $reasons += "No Description"
        }
        
        # Check 3: High Priority without being System
        if ($p.PriorityClass -eq "RealTime" -or $p.PriorityClass -eq "High") {
             if ($p.Path -notmatch "Windows\\System32") {
                $score += 30
                $reasons += "Abnormal High Priority"
             }
        }
        
        if ($score -ge 40) {
            $suspicious += [PSCustomObject]@{
                Process = $p.Name
                Id = $p.Id
                RiskScore = $score
                Reasons = ($reasons -join ", ")
                Path = $p.Path
            }
        }
    }
    
    return $suspicious
}

Export-ModuleMember -Function Get-ProcessTree, Get-SuspiciousProcesses
