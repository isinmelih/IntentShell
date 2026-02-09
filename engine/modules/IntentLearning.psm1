# IntentShell Intent Learning Module
# Personalization, Feedback Loop, and IntentDNA
#
# IntentDNA:
# Tracks the evolution of intents over time.
# { 
#   first_seen, 
#   variations, 
#   success_rate, 
#   avg_risk, 
#   preferred_modules 
# }

using module .\SystemCore.psm1

class IntentDNA {
    [datetime]$FirstSeen
    [datetime]$LastSeen
    [int]$UsageCount
    [int]$SuccessCount
    [System.Collections.ArrayList]$Variations
    [hashtable]$PreferredModules # ModuleName -> Count
    
    IntentDNA() {
        $this.FirstSeen = Get-Date
        $this.LastSeen = Get-Date
        $this.UsageCount = 0
        $this.SuccessCount = 0
        $this.Variations = [System.Collections.ArrayList]::new()
        $this.PreferredModules = @{}
    }
}

$Global:UserAliases = @{}
$Global:IntentDNADatabase = @{} # IntentKey -> IntentDNA

function Update-IntentDNA {
    <#
    .SYNOPSIS
    Updates the DNA for a given intent based on execution results.
    #>
    [CmdletBinding()]
    param(
        [string]$Intent,
        [string]$OriginModule,
        [bool]$Success
    )
    
    $key = $Intent.Trim().ToLower()
    
    if (-not $Global:IntentDNADatabase.ContainsKey($key)) {
        $Global:IntentDNADatabase[$key] = [IntentDNA]::new()
    }
    
    $dna = $Global:IntentDNADatabase[$key]
    $dna.LastSeen = Get-Date
    $dna.UsageCount++
    if ($Success) { $dna.SuccessCount++ }
    
    if (-not $dna.Variations.Contains($Intent)) {
        $dna.Variations.Add($Intent) | Out-Null
    }
    
    if ($OriginModule) {
        if (-not $dna.PreferredModules.ContainsKey($OriginModule)) {
            $dna.PreferredModules[$OriginModule] = 0
        }
        $dna.PreferredModules[$OriginModule]++
    }
}

function Get-IntentDNA {
    <#
    .SYNOPSIS
    Retrieves the DNA for a specific intent or all intents.
    #>
    [CmdletBinding()]
    param(
        [string]$Intent
    )
    
    if ($Intent) {
        return $Global:IntentDNADatabase[$Intent.Trim().ToLower()]
    }
    return $Global:IntentDNADatabase
}

function Register-UserAlias {
    <#
    .SYNOPSIS
    Teaches IntentShell a new alias or preference.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Phrase,
        
        [Parameter(Mandatory=$true)]
        [string]$Intent
    )
    
    $Global:UserAliases[$Phrase] = $Intent
    Write-Output "Learned: '$Phrase' -> '$Intent'"
}

function Get-CommandFeedback {
    <#
    .SYNOPSIS
    Returns list of learned aliases.
    #>
    return $Global:UserAliases
}

class IntentLearningModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    IntentLearningModule() {
        $this.Name = "IntentLearning"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['System'] = 'ReadWrite'
        $this.Description = "Personalization and Feedback Module"
    }

    [ModuleResult] Run([ExecutionPlan]$Plan, [SystemContext]$Context) {
        # Auto-Learn from Plan Execution
        # This module can also be called explicitly, but here we hook into the lifecycle
        # In a real system, SystemCore would trigger a "OnPostExecute" event.
        # For now, we assume explicit calls for 'Learning:...' actions.
        
        switch ($Plan.Executable) {
            "Learning:Register" {
                if ($Plan.Args.Count -lt 2) { throw "Learning:Register requires Phrase and Intent." }
                Register-UserAlias -Phrase $Plan.Args[0] -Intent $Plan.Args[1]
            }
            "Learning:Feedback" {
                return [ModuleResult]::new($true, (Get-CommandFeedback | Out-String))
            }
            "Learning:UpdateDNA" {
                # Internal use mainly
                Update-IntentDNA -Intent $Plan.OriginalIntent -OriginModule $Plan.OriginModule -Success ($Plan.Status -eq [ExecutionStatus]::Completed)
                return [ModuleResult]::new($true, "DNA Updated")
            }
            "Learning:GetDNA" {
                return [ModuleResult]::new($true, (Get-IntentDNA -Intent $Plan.OriginalIntent))
            }
            default {
                throw "Action '$($Plan.Executable)' is not supported by IntentLearningModule."
            }
        }
        return [ModuleResult]::new($false, "Fallthrough")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([IntentLearningModule]::new())
}

Export-ModuleMember -Function Register-UserAlias, Get-CommandFeedback, Get-IntentDNA, Update-IntentDNA