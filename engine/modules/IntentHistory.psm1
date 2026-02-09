
using module .\SystemCore.psm1

# IntentShell Command Memory Module
# "Remember what I did last time"

$Global:IntentHistoryStore = @()

function Add-IntentHistory {
    <#
    .SYNOPSIS
    Saves a command execution to history with context.
    #>
    [CmdletBinding()]
    param(
        [string]$Intent,
        [string]$Command,
        [string]$Result = "Success"
    )
    
    $entry = [PSCustomObject]@{
        Id = [Guid]::NewGuid().ToString()
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Intent = $Intent
        Command = $Command
        ContextPath = (Get-Location).Path
        Result = $Result
    }
    
    $Global:IntentHistoryStore += $entry
}

function Search-IntentHistory {
    <#
    .SYNOPSIS
    Finds past commands based on intent or context.
    #>
    [CmdletBinding()]
    param(
        [string]$Query,
        [switch]$CurrentPathOnly
    )
    
    $results = $Global:IntentHistoryStore
    
    if ($CurrentPathOnly) {
        $current = (Get-Location).Path
        $results = $results | Where-Object { $_.ContextPath -eq $current }
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Query)) {
        $results = $results | Where-Object { $_.Intent -match $Query -or $_.Command -match $Query }
    }
    
    return $results | Select-Object -Last 5
}

class IntentHistoryModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    IntentHistoryModule() {
        $this.Name = "IntentHistory"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['System'] = 'ReadWrite'
        $this.Description = "Command History Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "History:Add" {
                    if ($Plan.Arguments.Count -lt 2) { return [ModuleResult]::new($false, "History:Add requires Intent and Command.") }
                    Add-IntentHistory -Intent $Plan.Arguments[0] -Command $Plan.Arguments[1]
                    return [ModuleResult]::new($true, "History Added")
                }
                "History:Search" {
                    $q = ""
                    if ($Plan.Arguments.Count -ge 1) { $q = $Plan.Arguments[0] }
                    $res = Search-IntentHistory -Query $q
                    $mr = [ModuleResult]::new($true, "Search Complete")
                    $mr.Data = $res
                    return $mr
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by IntentHistoryModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([IntentHistoryModule]::new())
}

Export-ModuleMember -Function Add-IntentHistory, Search-IntentHistory