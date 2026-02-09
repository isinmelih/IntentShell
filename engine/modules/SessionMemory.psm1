# SessionMemory.psm1
# Daily Life Killer Feature: Memory Assistant.
# Remembers session context and enables "Replay".

using module .\SystemCore.psm1

class SessionMemory {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    SessionMemory() {
        $this.Name = "SessionMemory"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['Memory'] = 'Session'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [string]) {
            switch ($InputData) {
                "LastCommand" { return [SessionMemory]::GetLastCommand() }
                "Summary" { return [SessionMemory]::GetSessionSummary() }
            }
        }
        return [ModuleResult]::new($false, "Unknown Memory Request. Valid: 'LastCommand', 'Summary'")
    }

    static [ModuleResult] GetLastCommand() {
        $history = [SystemCore]::GetExecutionHistory()
        $latest = $null
        
        foreach ($plan in $history.Values) {
            if ($plan.Status -eq [ExecutionStatus]::Completed) {
                if (-not $latest -or $plan.EndTime -gt $latest.EndTime) {
                    $latest = $plan
                }
            }
        }
        
        if ($latest) {
            return [ModuleResult]::new($true, "Found Last Command", $latest)
        }
        return [ModuleResult]::new($false, "No completed commands in history")
    }

    static [ModuleResult] GetSessionSummary() {
        $history = [SystemCore]::GetExecutionHistory()
        $count = $history.Count
        $success = 0
        $failed = 0
        $dirs = @{}

        foreach ($plan in $history.Values) {
            if ($plan.Status -eq [ExecutionStatus]::Completed) { $success++ }
            elseif ($plan.Status -eq [ExecutionStatus]::Failed) { $failed++ }
            
            if ($plan.ContextSnapshot -and $plan.ContextSnapshot['CWD']) {
                $dirs[$plan.ContextSnapshot['CWD']] = $true
            }
        }

        $summary = "Session Summary:`n" +
                   "  Total Commands: $count`n" +
                   "  Success: $success`n" +
                   "  Failed: $failed`n" +
                   "  Active Directories: $($dirs.Keys -join ', ')"
                   
        return [ModuleResult]::new($true, $summary)
    }
}

# Auto-Register
if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([SessionMemory]::new())
}