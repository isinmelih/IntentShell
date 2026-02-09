# ContextMood.psm1
# Analyzes context (Time, Interactivity) to set the System Mood.
# Affects risk tolerance and creative module activation.

using module .\SystemCore.psm1

class ContextMood {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    ContextMood() {
        $this.Name = "ContextMood"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['Context'] = 'Mood'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        # Determine Mood based on Environment
        
        $mood = "Standard"
        $hour = (Get-Date).Hour
        $day = (Get-Date).DayOfWeek
        
        # 1. Time-based Mood
        if ($hour -ge 23 -or $hour -lt 5) {
            $mood = "Cautious" # Late night coding -> High Risk of mistakes -> Stricter Governor
        }
        elseif ($hour -ge 9 -and $hour -lt 12) {
            $mood = "Focus" # Morning deep work
        }
        elseif ($hour -ge 18) {
            $mood = "Creative" # Evening exploration
        }
        
        # 2. Weekend Mode
        if ($day -eq "Saturday" -or $day -eq "Sunday") {
            if ($mood -ne "Cautious") {
                $mood = "Creative"
            }
        }
        
        # 3. Interactivity Check
        # If running in non-interactive script, force "Robot" or "Standard"
        if (-not $Context.IsInteractive) {
            $mood = "Robot" # Disable creative distractions
        }
        
        return [ModuleResult]::new($true, $mood)
    }
}

# Auto-Register
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([ContextMood]::new())
}