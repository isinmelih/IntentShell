
using module .\SystemCore.psm1

# IntentShell Security Inspection Module
# Defensive Security Auditing

function Get-StartupItems {
    <#
    .SYNOPSIS
    Lists persistence mechanisms (Startup Folder & Registry).
    #>
    [CmdletBinding()]
    param()
    
    $results = @()
    
    # 1. Startup Folder
    $startupPath = [Environment]::GetFolderPath("Startup")
    if (Test-Path $startupPath) {
        Get-ChildItem $startupPath | ForEach-Object {
            $results += [PSCustomObject]@{
                Type = "StartupFolder"
                Name = $_.Name
                Path = $_.FullName
                Details = "User Startup"
            }
        }
    }
    
    # 2. Registry Run Keys (HKCU/HKLM)
    $keys = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
              "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run")
              
    foreach ($key in $keys) {
        if (Test-Path $key) {
            Get-Item $key | Select-Object -ExpandProperty Property | ForEach-Object {
                $value = (Get-ItemProperty $key).$_
                $results += [PSCustomObject]@{
                    Type = "RegistryRun"
                    Name = $_
                    Path = $value
                    Details = $key
                }
            }
        }
    }
    
    return $results
}

function Get-SecurityStatus {
    <#
    .SYNOPSIS
    Checks AV and Firewall status.
    #>
    [CmdletBinding()]
    param()
    
    $av = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction SilentlyContinue
    $firewall = Get-NetFirewallProfile -Profile Domain,Public,Private | Select-Object Name, Enabled
    
    [PSCustomObject]@{
        Antivirus = if ($av) { $av.displayName } else { "Not Detected/WMI Error" }
        AVState = if ($av) { $av.productState } else { "Unknown" }
        Firewall = $firewall
    }
}

class SecurityInspectionModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    SecurityInspectionModule() {
        $this.Name = "SecurityInspection"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['system'] = 'read'
        $this.Capabilities['registry'] = 'read'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        # Check if plan involves system modification or high risk
        # For now, just run a quick health check or pass
        
        $Plan = $null
        if ($InputData -is [ExecutionPlan]) {
             $Plan = $InputData
        }

        if ($Plan -and ($Plan.RiskLevel -eq 'High' -or $Plan.RiskLevel -eq 'Critical')) {
             # Perform deeper check
             $secStatus = Get-SecurityStatus
             if ($secStatus.Antivirus -eq "Not Detected/WMI Error") {
                 return [ModuleResult]::new($false, "Security Risk: Antivirus not detected for High Risk operation.")
             }
        }
        return [ModuleResult]::new($true, "Security Inspection Passed")
    }
}

# Register Module
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([SecurityInspectionModule]::new())
}

Export-ModuleMember -Function Get-StartupItems, Get-SecurityStatus
