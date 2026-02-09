using module .\SystemCore.psm1

# IntentShell Experimental Lab Module
# Management of Opt-In Experimental Features

function Get-ExperimentalFeatures {
    <#
    .SYNOPSIS
    Lists available experimental flags and their status.
    #>
    [CmdletBinding()]
    param()
    
    # In a real scenario, this would check a config file or global state
    $features = @(
        @{ Name="KernelDriver"; Status="Disabled"; Risk="High"; Description="Direct Kernel Memory Access" },
        @{ Name="GhostMode"; Status="Disabled"; Risk="Medium"; Description="Stealth Process Inspection" }
    )
    
    if ($Global:IntentShellConfig.ExperimentalModeEnabled) {
        $features[0].Status = "Enabled"
    }
    
    return $features
}

function Join-ExperimentalMode {
    <#
    .SYNOPSIS
    The official command to join the experimental program.
    #>
    [CmdletBinding()]
    param()
    
    Write-Warning "Experimental Mode activation must be initiated via the '/features:' command prefix in the main interface."
    Write-Output "Use: /features:intentshell kernel experimental join"
}

class ExperimentalLabModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    ExperimentalLabModule() {
        $this.Name = "ExperimentalLab"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['System'] = 'ReadWrite'
        $this.Description = "Experimental Features Management Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Experimental:List" {
                    $res = Get-ExperimentalFeatures
                    $mr = [ModuleResult]::new($true, "Experimental Features Listed")
                    $mr.Data = $res
                    return $mr
                }
                "Experimental:Join" {
                    Join-ExperimentalMode
                    return [ModuleResult]::new($true, "Instruction displayed.")
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by ExperimentalLabModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([ExperimentalLabModule]::new())
}

Export-ModuleMember -Function Get-ExperimentalFeatures, Join-ExperimentalMode