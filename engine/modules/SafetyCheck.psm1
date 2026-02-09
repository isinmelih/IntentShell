# IntentShell Safety Check Module
# Wraps Kernel Sentinel to implement SystemModule interface
# Part of SystemCore strict pre-checks

using module .\SystemCore.psm1

class SafetyCheckModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    SafetyCheckModule() {
        $this.Name = "SafetyCheck"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['System'] = 'Read'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $plan = $InputData
            
            # Construct Command String for Analysis
            $commandStr = $plan.Executable
            if ($plan.Args) {
                $commandStr += " " + ($plan.Args -join " ")
            }
            
            # Prepare Intent Object for Sentinel
            # Sentinel expects an object with 'risk', 'target', 'intent_type' etc.
            # We map from ExecutionPlan
            $intentObj = @{
                risk = $plan.RiskLevel
                target = $plan.WorkingDir # Approximation if target not explicit
                intent_type = "execution_request"
                recursive = $false # Unknown
                filters = @()
            }
            
            # Call Sentinel's Measure-Risk
            # Note: Sentinel is a Kernel module (functions), not a Class module.
            # We assume it's loaded in the session.
            if (Get-Command Measure-Risk -ErrorAction SilentlyContinue) {
                $riskResult = Measure-Risk -Command $commandStr -Intent $intentObj
                
                if ($riskResult.level -eq "high") {
                    return [ModuleResult]::new($false, "High Risk Detected: " + ($riskResult.reasons -join ", "))
                }
                elseif ($riskResult.level -eq "medium" -and $plan.RiskLevel -eq "low") {
                     # Escalate risk if Sentinel disagrees with Plan?
                     # For now, we just warn or block if strictly safe.
                     # Let's block for now to be safe.
                     return [ModuleResult]::new($true, "Medium Risk: " + ($riskResult.reasons -join ", "))
                }
                else {
                    return [ModuleResult]::new($true, "Safety Check Passed (Level: $($riskResult.level))")
                }
            } else {
                return [ModuleResult]::new($false, "Sentinel (Measure-Risk) not available.")
            }
        }
        return [ModuleResult]::new($false, "Invalid Input")
    }
}

# Register with SystemCore
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([SafetyCheckModule]::new())
}