# IntentShell Environment Manager
# "Switch to the right project context"
# Integrated with SystemCore as a PreCheck module.

using module .\SystemCore.psm1

class EnvManagerModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    EnvManagerModule() {
        $this.Name = "EnvManager"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['Env'] = 'ReadWrite'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $plan = $InputData
            # Use plan's working directory, default to current location if empty
            $path = if ([string]::IsNullOrEmpty($plan.WorkingDir)) { (Get-Location).Path } else { $plan.WorkingDir }
            
            $messages = @()
            
            # 1. Python Venv
            if (Test-Path "$path\venv\Scripts\Activate.ps1") {
                $messages += "Python venv detected"
                # We update the plan's environment variables. 
                # SystemCore/ExecutionEngine must apply these before running the command.
                $plan.Env["VIRTUAL_ENV"] = "$path\venv"
                # Note: Modifying Path in Env hash might be complex to merge later, 
                # but we store the intent here.
                # For now, we assume ExecutionEngine prepends these.
                $plan.Env["Path_Prepend"] = "$path\venv\Scripts" 
            }
            
            # 2. Node Version (.nvmrc)
            if (Test-Path "$path\.nvmrc") {
                $version = Get-Content "$path\.nvmrc" -Raw
                $messages += "Node version requirement: $version"
                # Logic to actually switch node would go here (e.g. updating Path to specific node version)
            }
            
            if ($messages.Count -gt 0) {
                return [ModuleResult]::new($true, "EnvManager: " + ($messages -join ", "))
            } else {
                return [ModuleResult]::new($true, "EnvManager: No specific environment context found.")
            }
        }
        
        return [ModuleResult]::new($false, "EnvManager requires ExecutionPlan input.")
    }
}

# Register with SystemCore
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([EnvManagerModule]::new())
}

function Enable-ProjectEnvironment {
    <#
    .SYNOPSIS
    Legacy wrapper for manual environment activation.
    #>
    [CmdletBinding()]
    param()
    
    Write-Warning "Enable-ProjectEnvironment is deprecated. Use SystemCore execution flow."
    # We can invoke the module logic manually if needed, but for now just warn.
}

Export-ModuleMember -Function Enable-ProjectEnvironment