# ProactiveSuggestion.psm1
# Analyzes history and context to offer helpful suggestions.
# Transforms IntentShell from passive tool to active assistant.

using module .\SystemCore.psm1

class ProactiveSuggestion {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    ProactiveSuggestion() {
        $this.Name = "ProactiveSuggestion"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['Assistance'] = 'Suggestion'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        $suggestions = @()
        
        # 1. Analyze Input (Last Plan)
        if ($InputData -is [ExecutionPlan]) {
            $lastPlan = $InputData
            
            # Suggestion: Test -> Coverage
            if ($lastPlan.OriginalIntent -match "test" -and $lastPlan.Status -eq [ExecutionStatus]::Completed) {
                $suggestions += "💡 Suggestion: You just ran tests. Do you want to see a coverage report?"
            }
            
            # Suggestion: Git Commit -> Push
            if ($lastPlan.OriginalIntent -match "commit" -and $lastPlan.Status -eq [ExecutionStatus]::Completed) {
                $suggestions += "💡 Suggestion: Changes committed. Don't forget to 'push'!"
            }
            
            # Suggestion: Failure -> Diagnosis
            if ($lastPlan.Status -eq [ExecutionStatus]::Failed) {
                 $suggestions += "💡 Suggestion: The command failed. Try 'Analyze Error' to debug."
            }
        }
        
        # 2. Analyze Environment (Global Suggestions)
        if ($Context.Mood -eq "Creative") {
             $suggestions += "💡 Tip: You are in Creative Mode. Try asking 'What if I delete the kernel?' to see a simulation."
        }
        
        if ($suggestions.Count -gt 0) {
            return [ModuleResult]::new($true, $suggestions -join "`n")
        }
        
        return [ModuleResult]::new($true, "") # No suggestion is valid
    }
}

# Auto-Register
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([ProactiveSuggestion]::new())
}