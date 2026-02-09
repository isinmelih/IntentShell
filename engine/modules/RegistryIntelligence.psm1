using module .\SystemCore.psm1

# IntentShell Registry Intelligence Module
# Smart Registry Analysis

function Analyze-RegistryKey {
    <#
    .SYNOPSIS
    Provides intelligence about a specific registry key.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "Registry path not found."
        return
    }
    
    $item = Get-Item $Path
    $props = $item.Property
    
    # Basic Heuristics for Risk
    $risk = "Low"
    $warnings = @()
    
    if ($Path -match "Run" -or $Path -match "RunOnce") {
        $risk = "Medium"
        $warnings += "Persistence Mechanism"
    }
    
    if ($Path -match "Policies") {
        $risk = "High"
        $warnings += "System Policy - Often used to disable security features"
    }
    
    [PSCustomObject]@{
        Path = $Path
        KeyCount = $item.SubKeyCount
        ValueCount = $item.Property.Count
        RiskLevel = $risk
        Warnings = ($warnings -join ", ")
    }
}

function Get-RegistryDiff {
    <#
    .SYNOPSIS
    Snapshots and compares registry keys (Simplified).
    #>
    [CmdletBinding()]
    param(
        [string]$Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    )
    
    # This is a placeholder for a stateful diff engine.
    # For now, it just returns current state.
    Write-Warning "Registry Diff requires a baseline. Showing current state only."
    Get-ItemProperty $Path
}

class RegistryIntelligenceModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    RegistryIntelligenceModule() {
        $this.Name = "RegistryIntelligence"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Read'
        $this.Description = "Smart Registry Analysis Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Registry:Analyze" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Registry:Analyze requires Path argument.") }
                    $res = Analyze-RegistryKey -Path $Plan.Arguments[0]
                    $mr = [ModuleResult]::new($true, "Registry Analysis Complete")
                    $mr.Data = $res
                    return $mr
                }
                "Registry:Diff" {
                    $p = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                    if ($Plan.Arguments.Count -ge 1) { $p = $Plan.Arguments[0] }
                    $res = Get-RegistryDiff -Path $p
                    $mr = [ModuleResult]::new($true, "Registry Diff Complete")
                    $mr.Data = $res
                    return $mr
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by RegistryIntelligenceModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([RegistryIntelligenceModule]::new())
}

Export-ModuleMember -Function Analyze-RegistryKey, Get-RegistryDiff
