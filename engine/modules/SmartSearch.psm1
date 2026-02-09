using module .\SystemCore.psm1

# IntentShell Smart Search Module
# "Find where auth is handled"

function Search-ProjectCode {
    <#
    .SYNOPSIS
    Context-aware code search (grep-like).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern,
        
        [string[]]$Include = @("*.py", "*.ps1", "*.js", "*.ts", "*.rs", "*.c", "*.cpp", "*.h", "*.java"),
        [string[]]$Exclude = @("node_modules", ".git", "venv", "__pycache__", "target", "bin", "obj")
    )
    
    Write-Verbose "Searching for '$Pattern'..."
    
    $results = Get-ChildItem -Path . -Recurse -Include $Include -Exclude $Exclude -ErrorAction SilentlyContinue | 
        Select-String -Pattern $Pattern -SimpleMatch:$false | 
        Select-Object Path, LineNumber, Line
        
    if ($results) {
        # Group by file for cleaner output
        return $results | Group-Object Path | Select-Object Name, Count, @{N='Matches';E={$_.Group | Select-Object LineNumber, Line}}
    } else {
        return "No matches found."
    }
}

class SmartSearchModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    SmartSearchModule() {
        $this.Name = "SmartSearch"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Read'
        $this.Description = "Context-aware Code Search Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Search:Code" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Search:Code requires Pattern argument.") }
                    $pattern = $Plan.Arguments[0]
                    
                    $params = @{ Pattern = $pattern }
                    if ($Plan.Parameters -and $Plan.Parameters.ContainsKey('Include')) {
                        $params['Include'] = $Plan.Parameters['Include']
                    }
                    if ($Plan.Parameters -and $Plan.Parameters.ContainsKey('Exclude')) {
                        $params['Exclude'] = $Plan.Parameters['Exclude']
                    }
                    
                    $res = Search-ProjectCode @params
                    $mr = [ModuleResult]::new($true, "Search Complete")
                    $mr.Data = $res
                    return $mr
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by SmartSearchModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([SmartSearchModule]::new())
}

Export-ModuleMember -Function Search-ProjectCode
