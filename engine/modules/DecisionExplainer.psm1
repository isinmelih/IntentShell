# DecisionExplainer.psm1
# Builds trust by explaining WHY a decision was made.
# Analyzes ExecutionHistory to generate human-readable reports.

using module .\SystemCore.psm1

class DecisionExplainer {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    DecisionExplainer() {
        $this.Name = "DecisionExplainer"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['Explainability'] = 'Decision'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [string]) { # Expecting Plan ID
            return [DecisionExplainer]::ExplainDecision($InputData)
        }
        return [ModuleResult]::new($false, "Input must be Execution Plan ID")
    }

    static [ModuleResult] ExplainDecision([string]$PlanId) {
        if (-not [SystemCore]::ExecutionHistory.ContainsKey($PlanId)) {
             return [ModuleResult]::new($false, "Plan ID '$PlanId' not found in history.")
        }
        
        $plan = [SystemCore]::ExecutionHistory[$PlanId]
        
        $explanation = "🧾 Decision Explanation Report`n" +
                       "----------------------------`n" +
                       "Plan ID : $($plan.Id)`n" +
                       "Intent  : $($plan.OriginalIntent)`n" +
                       "Status  : $($plan.Status)`n" +
                       "Module  : $($plan.OriginModule)`n" +
                       "Risk    : $($plan.RiskLevel)`n"
                       
        if ($plan.Status -eq [ExecutionStatus]::Blocked) {
            $explanation += "`n❌ BLOCKED`n" +
                            "   Reason: $($plan.BlockReason)`n"
            
            # Contextual hints
            if ($plan.ConfidenceScore -lt 40 -and $plan.ConfidenceScore -gt 0) {
                $explanation += "   Insight: Confidence Score ($($plan.ConfidenceScore)) was too low.`n"
            }
        }
        elseif ($plan.Status -eq [ExecutionStatus]::Failed) {
            $explanation += "`n⚠️ FAILED`n" +
                            "   Reason: $($plan.BlockReason)`n" # We store failure msg in BlockReason or separate field? SystemCore uses BlockReason for failures too sometimes
        }
        elseif ($plan.Status -eq [ExecutionStatus]::Completed) {
             $explanation += "`n✅ EXECUTED`n" +
                             "   Duration: $($plan.EndTime - $plan.StartTime)`n"
        }
        
        return [ModuleResult]::new($true, $explanation)
    }
}

# Auto-Register
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([DecisionExplainer]::new())
}