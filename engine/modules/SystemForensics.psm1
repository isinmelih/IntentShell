using module .\SystemCore.psm1

# IntentShell System Forensics Module
# Read-Only Forensic Analysis

function Get-RecentEvents {
    <#
    .SYNOPSIS
    Analyzes recent critical system events (Security & System).
    #>
    [CmdletBinding()]
    param(
        [int]$Hours = 24
    )
    
    $time = (Get-Date).AddHours(-$Hours)
    
    Write-Verbose "Scanning Event Logs since $time..."
    
    $events = Get-WinEvent -FilterHashtable @{LogName='System','Security'; StartTime=$time; Level=1,2} -ErrorAction SilentlyContinue | Select-Object -First 100
    
    return $events | Select-Object TimeCreated, Id, LevelDisplayName, Message
}

function Get-PrefetchAnalysis {
    <#
    .SYNOPSIS
    Lists recently executed applications from Prefetch (Requires Admin).
    #>
    [CmdletBinding()]
    param()
    
    $prefetchPath = "C:\Windows\Prefetch"
    if (-not (Test-Path $prefetchPath)) {
        Write-Error "Access to Prefetch denied or path not found."
        return
    }
    
    Get-ChildItem $prefetchPath -Filter "*.pf" | Sort-Object LastWriteTime -Descending | Select-Object -First 20 | Select-Object Name, LastWriteTime
}

class SystemForensicsModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    SystemForensicsModule() {
        $this.Name = "SystemForensics"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Read'
        $this.Description = "Read-Only Forensic Analysis Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Forensics:Events" {
                    $hours = 24
                    if ($Plan.Arguments.Count -ge 1) { $hours = [int]$Plan.Arguments[0] }
                    $res = Get-RecentEvents -Hours $hours
                    $mr = [ModuleResult]::new($true, "Forensic Events Retrieved")
                    $mr.Data = $res
                    return $mr
                }
                "Forensics:Prefetch" {
                    $res = Get-PrefetchAnalysis
                    $mr = [ModuleResult]::new($true, "Prefetch Analysis Complete")
                    $mr.Data = $res
                    return $mr
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by SystemForensicsModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([SystemForensicsModule]::new())
}

Export-ModuleMember -Function Get-RecentEvents, Get-PrefetchAnalysis
