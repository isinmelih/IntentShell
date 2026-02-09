using module .\SystemCore.psm1

# IntentShell Explainable Actions Module
# Educational layer that explains "Why" and "How"

function Get-ActionExplanation {
    <#
    .SYNOPSIS
    Explains a PowerShell command in plain language.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    $explanation = @{
        Command = $Command
        Breakdown = @()
        RiskFactors = @()
    }
    
    # Simple Tokenizer/Parser Logic (Mockup for now, would be LLM powered ideally)
    $tokens = [System.Management.Automation.PSParser]::Tokenize($Command, [ref]$null)
    
    foreach ($token in $tokens) {
        if ($token.Type -eq "Command") {
            $cmdName = $token.Content
            try {
                $help = Get-Help $cmdName -ErrorAction SilentlyContinue
                $desc = if ($help) { $help.Synopsis } else { "Unknown Command" }
                $explanation.Breakdown += [PSCustomObject]@{
                    Part = $cmdName
                    Type = "Command"
                    Meaning = $desc
                }
            } catch {}
        }
        elseif ($token.Type -eq "Parameter") {
            $explanation.Breakdown += [PSCustomObject]@{
                Part = $token.Content
                Type = "Parameter"
                Meaning = "Modifies behavior of the command"
            }
        }
    }
    
    # Educational Tip
    if ($Command -match "Force") {
        $explanation.RiskFactors += "Uses -Force: Bypasses confirmation prompts."
    }
    if ($Command -match "Remove-") {
        $explanation.RiskFactors += "Destructive Action: Deletes data."
    }
    
    return [PSCustomObject]$explanation
}

class ExplainableActionsModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    ExplainableActionsModule() {
        $this.Name = "ExplainableActions"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Read'
        $this.Description = "Educational Explanation Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Explain:Command" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Explain:Command requires Command argument.") }
                    $res = Get-ActionExplanation -Command $Plan.Arguments[0]
                    $mr = [ModuleResult]::new($true, "Explanation Generated")
                    $mr.Data = $res
                    return $mr
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by ExplainableActionsModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([ExplainableActionsModule]::new())
}

Export-ModuleMember -Function Get-ActionExplanation
