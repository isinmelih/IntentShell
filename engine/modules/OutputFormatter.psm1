using module .\SystemCore.psm1

# IntentShell Output Formatter
# "Make it look human"

function Format-HumanReadable {
    <#
    .SYNOPSIS
    Transforms raw objects into human-friendly text summaries.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        $InputObject
    )
    
    process {
        if ($InputObject -is [System.IO.FileInfo]) {
            return "File: $($InputObject.Name) (Size: $([math]::Round($InputObject.Length/1KB, 2)) KB)"
        }
        
        if ($InputObject -is [System.Diagnostics.Process]) {
            return "Process: $($InputObject.Name) (PID: $($InputObject.Id)) - Status: Running"
        }
        
        # Fallback to standard formatting but cleaner
        return $InputObject | Format-List | Out-String -Stream | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }
}

class OutputFormatterModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    OutputFormatterModule() {
        $this.Name = "OutputFormatter"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Read'
        $this.Description = "Human Readable Output Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Format:Human" {
                    return [ModuleResult]::new($true, "OutputFormatter is a pipeline tool. Use 'Format-HumanReadable'.")
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by OutputFormatterModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([OutputFormatterModule]::new())
}

Export-ModuleMember -Function Format-HumanReadable
