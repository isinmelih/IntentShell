using module .\SystemCore.psm1

# IntentShell Auto-Fix Module
# "It broke, fix it."

function Invoke-AutoFixSuggestion {
    <#
    .SYNOPSIS
    Analyzes the last error and suggests fixes.
    #>
    [CmdletBinding()]
    param()
    
    $lastError = $Global:Error[0]
    if (-not $lastError) {
        Write-Output "No recent errors found to analyze."
        return
    }
    
    $msg = $lastError.Exception.Message
    $suggestion = "Unknown Error"
    
    if ($msg -match "is not recognized as the name of a cmdlet") {
        $suggestion = "Command not found. Check spelling or install the required module/package."
        # Could integrate with 'winget search' here
    }
    elseif ($msg -match "Access to the path .* is denied") {
        $suggestion = "Permission Denied. Try running IntentShell as Administrator."
    }
    elseif ($msg -match "cannot find the file") {
        $suggestion = "File missing. Check the path or run 'ls' to verify."
    }
    
    [PSCustomObject]@{
        Error = $msg
        Suggestion = $suggestion
        AutoFixCommand = if ($suggestion -match "Administrator") { "Start-Process powershell -Verb RunAs" } else { $null }
    }
}

class AutoFixModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    AutoFixModule() {
        $this.Name = "AutoFix"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Read'
        $this.Description = "Error Analysis and Fix Suggestions Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "System:AutoFix" {
                    $res = Invoke-AutoFixSuggestion
                    $mr = [ModuleResult]::new($true, "AutoFix Analysis Complete")
                    $mr.Data = $res
                    return $mr
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by AutoFixModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([AutoFixModule]::new())
}

Export-ModuleMember -Function Invoke-AutoFixSuggestion
