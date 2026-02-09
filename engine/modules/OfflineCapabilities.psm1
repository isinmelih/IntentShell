using module .\SystemCore.psm1

# IntentShell Offline Capabilities
# "Works when the internet is down"

$Global:OfflineIntentCache = @{
    "list_files" = "Get-ChildItem"
    "check_ip" = "ipconfig"
    "system_info" = "Get-ComputerInfo"
}

function Get-CachedIntent {
    <#
    .SYNOPSIS
    Retrieves a fallback intent if online AI is unreachable.
    #>
    [CmdletBinding()]
    param(
        [string]$Query
    )
    
    # Simple keyword matching for offline fallback
    foreach ($key in $Global:OfflineIntentCache.Keys) {
        if ($Query -match $key) {
            return $Global:OfflineIntentCache[$key]
        }
    }
    
    return $null
}

class OfflineCapabilitiesModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    OfflineCapabilitiesModule() {
        $this.Name = "OfflineCapabilities"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Read'
        $this.Description = "Offline Fallback Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Offline:Get" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Offline:Get requires Query argument.") }
                    $res = Get-CachedIntent -Query $Plan.Arguments[0]
                    $mr = [ModuleResult]::new($true, "Offline Intent Retrieved")
                    $mr.Data = $res
                    return $mr
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by OfflineCapabilitiesModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([OfflineCapabilitiesModule]::new())
}

Export-ModuleMember -Function Get-CachedIntent
