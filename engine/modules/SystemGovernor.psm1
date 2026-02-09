# SystemGovernor.psm1
# The "Consciousness" of the system.
# Manages priority, conflicts, and vetoes between modules.

using module .\SystemCore.psm1

class SystemGovernor {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    static [GovernancePolicy]$Policy

    SystemGovernor() {
        $this.Name = "SystemGovernor"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['Governor'] = 'All'
        [SystemGovernor]::Policy = [GovernancePolicy]::new()
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            return [SystemGovernor]::ValidatePlan($InputData)
        }
        if ($InputData -is [array] -and $InputData.Count -gt 0 -and $InputData[0] -is [PlanCandidate]) {
            return [SystemGovernor]::ResolveConflict($InputData)
        }
        return [ModuleResult]::new($false, "Invalid Input for Governor")
    }

    static [ModuleResult] ValidatePlan([ExecutionPlan]$Plan) {
        # Veto Logic
        # Policy: Creative modules cannot run High Risk commands without strict oversight
        
        if ($Plan.OriginModule -match "Creative" -and $Plan.RiskLevel -eq "High") {
             # We don't necessarily block, but we might downgrade or flag it
             # For now, let's implement the user's "ConflictRule" idea loosely
             # If it's High Risk and from Creative, we might block it if we are in "Cautious" Mood (to be checked in SystemCore)
             
             # Hard Rule: Creative modules cannot execute destructive internal commands directly
             if ($Plan.Executable -match "Remove-Item|Delete|Format") {
                 $Plan.Status = [ExecutionStatus]::Blocked
                 $Plan.BlockReason = "Governor Veto: Creative modules cannot initiate destructive actions."
                 return [ModuleResult]::new($false, $Plan.BlockReason)
             }
        }

        # Policy: "System" modules generally get a pass unless explicitly risky
        
        return [ModuleResult]::new($true, "Governor Approved")
    }

    static [ModuleResult] ResolveConflict([PlanCandidate[]]$Candidates) {
        # Sort by Priority of SourceModule -> then Confidence
        
        $BestCandidate = $null
        $MaxScore = -1000

        foreach ($c in $Candidates) {
            $baseScore = $c.ConfidenceScore
            $weight = 0
            
            # Apply Policy Weights based on Source Module Name
            if ($c.SourceModule -match "Safety|Security") { 
                $weight = [SystemGovernor]::Policy.PriorityMap['Safety'] 
            }
            elseif ($c.SourceModule -match "Creative|Idea") { 
                $weight = [SystemGovernor]::Policy.PriorityMap['Creative'] 
            }
            else { 
                $weight = [SystemGovernor]::Policy.PriorityMap['System'] 
            }

            $finalScore = $baseScore + $weight
            
            # Log for debugging (in real system)
            # Write-Host "Candidate: $($c.SourceModule) Score: $finalScore"

            if ($finalScore -gt $MaxScore) {
                $MaxScore = $finalScore
                $BestCandidate = $c
            }
        }
        
        if ($BestCandidate) {
            return [ModuleResult]::new($true, "Conflict Resolved", $BestCandidate)
        }
        return [ModuleResult]::new($false, "No viable candidate")
    }
}

# Auto-Register
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([SystemGovernor]::new())
}