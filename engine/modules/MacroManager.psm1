using module .\SystemCore.psm1

# IntentShell Macro Manager
# "Do the morning routine"
# Now integrated with SystemCore for managed execution.

class MacroManagerModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    MacroManagerModule() {
        $this.Name = "MacroManager"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['Process'] = 'Spawn' # Required to execute macro steps
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
         return [ModuleResult]::new($false, "Not Implemented")
    }
}

# Register with SystemCore
# Note: SystemCore must be loaded before this module.
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([MacroManagerModule]::new())
} else {
    Write-Warning "SystemCore not loaded. MacroManager running in unmanaged mode (Risky)."
}

$Global:Macros = @{}
$Global:MacroConfigPath = "$PSScriptRoot\..\..\config\user_macros.ini"

function Load-Macros {
    if (Test-Path $Global:MacroConfigPath) {
        $Global:Macros = @{}
        try {
            $lines = Get-Content $Global:MacroConfigPath
            foreach ($line in $lines) {
                if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) { continue }
                # Split by first '=' only
                if ($line -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    $Global:Macros[$key] = $value
                }
            }
        } catch {
            Write-Warning "Failed to load macros from $Global:MacroConfigPath: $_"
        }
    }
}

# Initial Load
Load-Macros

function Set-MacroVariable {
    <#
    .SYNOPSIS
    Saves a user variable/macro to the .ini file while preserving comments.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Value
    )
    
    # Validation: No spaces in variable name
    if ($Name -match '\s') {
        Write-Error "Variable name '$Name' cannot contain spaces."
        return
    }

    # Remove leading # if present
    $Name = $Name -replace '^#', ''

    # Update Memory
    $Global:Macros[$Name] = $Value
    
    # Persist to .ini (Preserving Comments)
    if (-not (Test-Path $Global:MacroConfigPath)) {
        New-Item -Path $Global:MacroConfigPath -ItemType File -Force | Out-Null
    }

    $lines = Get-Content $Global:MacroConfigPath
    $newLines = @()
    $found = $false

    if ($lines) {
        foreach ($line in $lines) {
            # Check if this line defines our variable
            if ($line -match "^$Name=(.*)$") {
                $newLines += "$Name=$Value"
                $found = $true
            } else {
                $newLines += $line
            }
        }
    }

    if (-not $found) {
        $newLines += "$Name=$Value"
    }

    $newLines | Set-Content $Global:MacroConfigPath -Force
    
    Write-Output "Variable #$Name saved as '$Value'."
}

function Get-MacroVariable {
    param([string]$Name)
    # Remove leading # if present
    $Name = $Name -replace '^#', ''
    
    if ($Global:Macros.ContainsKey($Name)) {
        return $Global:Macros[$Name]
    }
    return $null
}

function Register-Macro {
    <#
    .SYNOPSIS
    Defines a sequence of commands as a macro (Legacy/Memory Only).
    For persistent variables, use Set-MacroVariable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string[]]$Commands
    )
    
    # If it's a single string, save it as a persistent variable
    if ($Commands.Count -eq 1) {
        Set-MacroVariable -Name $Name -Value $Commands[0]
    } else {
        # Legacy behavior for multi-step memory-only macros
        $Global:Macros[$Name] = $Commands
        Write-Warning "Multi-step macro '$Name' registered in MEMORY ONLY. Use single strings for persistence."
    }
}

function Invoke-Macro {
    <#
    .SYNOPSIS
    Executes a registered macro via SystemCore.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    # Remove leading #
    $Name = $Name -replace '^#', ''
    
    if (-not $Global:Macros.ContainsKey($Name)) {
        Write-Error "Macro '$Name' not found."
        return
    }
    
    $val = $Global:Macros[$Name]
    
    # Check if it is a list (Legacy) or string (New Variable)
    if ($val -is [string]) {
        # It's a command string, just execute it or return it?
        # The user intent says "#zoom" -> "Open C:..."
        # This function might be used to EXECUTE it directly.
        $cmd = $val
        Write-Host "Macro [$Name] >> Expanding to: $cmd" -ForegroundColor Cyan
        
        if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
             $plan = [SystemCore]::CreatePlan("Macro Expansion: $Name", "powershell", @("-c", $cmd))
             $plan.OriginModule = "MacroManager"
             [SystemCore]::RequestExecution($plan)
        } else {
             Invoke-Expression $cmd
        }
    } else {
        # Legacy Array Loop
        $steps = $val
        foreach ($cmd in $steps) {
            # ... existing logic ...
            Write-Host "Macro [$Name] >> Requesting Execution: $cmd" -ForegroundColor Cyan
            if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
                # Managed Execution
                # Naive parsing
                $parts = $cmd -split "\s+"
                $exe = $parts[0]
                $argsList = if ($parts.Count -gt 1) { $parts[1..($parts.Count-1)] } else { @() }
                
                $plan = [SystemCore]::CreatePlan("Macro Step: $cmd", $exe, $argsList)
                $plan.OriginModule = "MacroManager"
                $plan.RiskLevel = "Medium"
                
                $result = [SystemCore]::RequestExecution($plan)
            } else {
                Invoke-Expression $cmd
            }
        }
    }
}

Export-ModuleMember -Function Register-Macro, Invoke-Macro, Set-MacroVariable, Get-MacroVariable