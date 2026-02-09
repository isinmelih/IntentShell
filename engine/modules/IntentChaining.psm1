using module .\SystemCore.psm1

# IntentShell Intent Chaining Module
# Handles multi-step workflows and conditional execution
# Integrated with SystemCore

class IntentChainingModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    IntentChainingModule() {
        $this.Name = "IntentChaining"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['Process'] = 'Spawn'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
         return [ModuleResult]::new($false, "Not Implemented")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([IntentChainingModule]::new())
}

function Invoke-IntentChain {
    <#
    .SYNOPSIS
    Executes a sequence of commands with error handling and conditionals.
    .DESCRIPTION
    Implements a simple DAG (Directed Acyclic Graph) execution model via SystemCore.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Steps, # Array of command objects { command, continue_on_error }
        
        [switch]$StopOnError
    )
    
    $results = @()
    
    foreach ($step in $Steps) {
        $cmd = $step.command
        $desc = if ($step.description) { $step.description } else { $cmd }
        
        Write-Host "[Chain] Processing Step: $desc" -ForegroundColor Cyan
        
        try {
            # Parse command
            $parts = $cmd -split "\s+"
            $exe = $parts[0]
            $argsList = if ($parts.Count -gt 1) { $parts[1..($parts.Count-1)] } else { @() }
            
            if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
                 # Managed Execution
                 $plan = [SystemCore]::CreatePlan("Chain Step: $desc", $exe, $argsList)
                 $plan.OriginModule = "IntentChaining"
                 $plan.RiskLevel = "Medium" # Default for chained commands, could be parameterized
                 
                 $res = [SystemCore]::RequestExecution($plan)
                 
                 if ($res.Success) {
                     $results += @{ Step=$desc; Status="Success"; Output=$res.Message }
                 } else {
                     throw $res.Message
                 }
            } else {
                 # Legacy
                 Write-Warning "SystemCore not loaded. Using Invoke-Expression (UNSAFE)."
                 $res = Invoke-Expression $cmd
                 $results += @{ Step=$desc; Status="Success"; Output=$res }
            }
        }
        catch {
            Write-Error "[Chain] Failed: $desc - $_"
            $results += @{ Step=$desc; Status="Failed"; Error="$_" }
            
            if ($StopOnError -or -not $step.continue_on_error) {
                Write-Warning "[Chain] Execution halted due to error."
                break
            }
        }
    }
    
    return $results
}

Export-ModuleMember -Function Invoke-IntentChain