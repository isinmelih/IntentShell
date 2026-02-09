using module .\SystemCore.psm1

# IntentShell Network Awareness Module
# Intelligent Network Analysis (No Drivers needed)

function Get-ActiveConnections {
    <#
    .SYNOPSIS
    Maps active TCP connections to processes.
    #>
    [CmdletBinding()]
    param(
        [switch]$ExternalOnly
    )
    
    $conns = Get-NetTCPConnection | Where-Object State -eq Established
    
    if ($ExternalOnly) {
        $conns = $conns | Where-Object { 
            $_.RemoteAddress -notmatch "^127\." -and 
            $_.RemoteAddress -notmatch "^192\.168\." -and
            $_.RemoteAddress -notmatch "^10\." -and 
            $_.RemoteAddress -notmatch "^172\." 
        }
    }
    
    $results = @()
    foreach ($c in $conns) {
        try {
            $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
            $procName = if ($proc) { $proc.Name } else { "Unknown" }
            $path = if ($proc) { $proc.Path } else { "N/A" }
            
            $results += [PSCustomObject]@{
                Process = $procName
                PID = $c.OwningProcess
                Local = "$($c.LocalAddress):$($c.LocalPort)"
                Remote = "$($c.RemoteAddress):$($c.RemotePort)"
                Path = $path
            }
        } catch { continue }
    }
    
    return $results
}

class NetworkAwarenessModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    NetworkAwarenessModule() {
        $this.Name = "NetworkAwareness"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Read'
        $this.Description = "Intelligent Network Analysis Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Network:Connections" {
                    $ExternalOnly = $false
                    if ($Plan.Parameters -and $Plan.Parameters.ContainsKey('ExternalOnly')) {
                        $ExternalOnly = $Plan.Parameters['ExternalOnly']
                    }
                    $res = Get-ActiveConnections -ExternalOnly:$ExternalOnly
                    $mr = [ModuleResult]::new($true, "Network Analysis Complete")
                    $mr.Data = $res
                    return $mr
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by NetworkAwarenessModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([NetworkAwarenessModule]::new())
}

Export-ModuleMember -Function Get-ActiveConnections
