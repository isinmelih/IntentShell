using module .\SystemCore.psm1

# IntentShell Kernel Driver Manager
# Manages the lifecycle of the C# Realtime Driver (GhostDriver)
# Implements SystemModule to handle "Internal:*" execution plans.

class KernelDriverManager {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [bool]$DriverLoaded = $false

    KernelDriverManager() {
        $this.Name = "KernelDriverManager"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Ring0' 
        $this.Capabilities['Process'] = 'All'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        # Double-check safety flag (Redundant but safe)
        if (-not [SystemCore]::ExperimentalKernelMode) {
             return [ModuleResult]::new($false, "Experimental Kernel Mode is NOT enabled in SystemCore.")
        }

        # This module acts as both a Policy Enforcer (PreCheck) and an Executor (Internal)
        
        if ($InputData -is [ExecutionPlan]) {
            $plan = $InputData
            
            # 1. Execution Mode (Internal Command)
            if ($plan.Executable -eq "Internal:LoadDriver") {
                return $this.LoadDriverInternal()
            }
            elseif ($plan.Executable -eq "Internal:ReadMemory") {
                return $this.ReadMemoryInternal($plan.Args)
            }
            elseif ($plan.Executable -eq "Internal:GetProcessPath") {
                return $this.GetProcessPathInternal($plan.Args)
            }
            
            # 2. PreCheck Mode (if used as a check)
            # Pass through
        }
        
        return [ModuleResult]::new($false, "Unknown Command or Invalid Input")
    }

    [ModuleResult] LoadDriverInternal() {
        if ($this.DriverLoaded) { return [ModuleResult]::new($true, "Driver already loaded.") }
        
        try {
            Write-Host "🔌 Loading GhostDriver (C# Kernel Proxy)..." -ForegroundColor Cyan
            
            # Define Path
            $kernelPath = Join-Path ([SystemCore]::CurrentContext.ProjectRoot) "engine\kernel\GhostDriver.psm1"
            
            if (-not (Test-Path $kernelPath)) {
                 return [ModuleResult]::new($false, "GhostDriver not found at $kernelPath")
            }

            # Ensure Config allows it (Simulated)
            if (-not $Global:IntentShellConfig) { $Global:IntentShellConfig = @{} }
            $Global:IntentShellConfig.ExperimentalModeEnabled = $true
            
            # Import
            Import-Module $kernelPath -Force -ErrorAction Stop
            
            $this.DriverLoaded = $true
            return [ModuleResult]::new($true, "GhostDriver Loaded Successfully. Ring0 Bridge Active.")
        }
        catch {
            return [ModuleResult]::new($false, "Failed to load GhostDriver: $_")
        }
    }
    
    [ModuleResult] ReadMemoryInternal([string[]]$Args) {
        if (-not $this.DriverLoaded) { return [ModuleResult]::new($false, "Driver not loaded. Run Enable-KernelDriver first.") }
        
        $pidVal = $Args[0] -as [int]
        $addr = $Args[1] -as [long]
        $size = if ($Args.Count -gt 2) { $Args[2] -as [int] } else { 32 }
        
        try {
            $result = Invoke-GhostRead -Pid $pidVal -Address $addr -Size $size
            return [ModuleResult]::new($true, $result)
        }
        catch {
             return [ModuleResult]::new($false, "Kernel Read Failed: $_")
        }
    }

    [ModuleResult] GetProcessPathInternal([string[]]$Args) {
        if (-not $this.DriverLoaded) { return [ModuleResult]::new($false, "Driver not loaded.") }
        
        $pidVal = $Args[0] -as [int]
        try {
            $result = Get-GhostPath -Pid $pidVal
            return [ModuleResult]::new($true, $result)
        }
        catch {
             return [ModuleResult]::new($false, "GetPath Failed: $_")
        }
    }
}

# Helper Functions (User Interface)

function Enable-KernelDriver {
    <#
    .SYNOPSIS
    Activates the Experimental Kernel Driver.
    #>
    [CmdletBinding()]
    param()
    
    $plan = [SystemCore]::CreatePlan("Enable Kernel Driver", "Internal:LoadDriver", @())
    $plan.OriginModule = "KernelDriverManager"
    $plan.RiskLevel = "High"
    
    # Request Execution via SystemCore
    [SystemCore]::RequestExecution($plan)
}

function Read-KernelMemory {
    <#
    .SYNOPSIS
    Reads memory from a process using the Kernel Driver.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][int]$Pid,
        [long]$Address = 0,
        [int]$Size = 64
    )
    
    $plan = [SystemCore]::CreatePlan("Read Memory PID $Pid", "Internal:ReadMemory", @($Pid, $Address, $Size))
    $plan.OriginModule = "KernelDriverManager"
    $plan.RiskLevel = "Critical"
    
    [SystemCore]::RequestExecution($plan)
}

function Get-RealProcessPath {
    <#
    .SYNOPSIS
    Gets the true process path via Kernel Driver (bypassing hooks).
    #>
    [CmdletBinding()]
    param([int]$Pid)

    $plan = [SystemCore]::CreatePlan("Get Real Path PID $Pid", "Internal:GetProcessPath", @($Pid))
    $plan.OriginModule = "KernelDriverManager"
    $plan.RiskLevel = "High"
    
    [SystemCore]::RequestExecution($plan)
}

# Register Module
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([KernelDriverManager]::new())
}

Export-ModuleMember -Function Enable-KernelDriver, Read-KernelMemory, Get-RealProcessPath
