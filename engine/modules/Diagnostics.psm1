
using module .\SystemCore.psm1

# IntentShell Diagnostics Module
# Self-Health Check
# Integrated with SystemCore

class DiagnosticsModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    DiagnosticsModule() {
        $this.Name = "Diagnostics"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['System'] = 'Read'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
         return [ModuleResult]::new($false, "Not Implemented")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([DiagnosticsModule]::new())
}

function Invoke-HealthCheck {
    <#
    .SYNOPSIS
    Performs a self-diagnostic of the IntentShell environment.
    #>
    [CmdletBinding()]
    param()
    
    $status = @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        ExecutionPolicy = Get-ExecutionPolicy
        AdminRights = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        ModulesLoaded = (Get-Module -Name IntentShell*).Count
        LastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    }
    
    return $status
}

Export-ModuleMember -Function Invoke-HealthCheck