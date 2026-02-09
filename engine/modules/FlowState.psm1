# FlowState.psm1
# Manages Deep Work sessions and User Mood analysis
# Requires CreativeCore.psm1

using module .\CreativeCore.psm1
using module .\SystemCore.psm1

# Global variable is still useful for Prompt function access
$Global:IntentShellFlowState = @{
    IsActive = $false
    StartTime = $null
    Task = ""
}

class FlowStateModule : StatefulCreativeModule {
    FlowStateModule() : base("FlowState", "Session") {} # Session scope, resets on restart

    [CreativeOutput] Run([string]$Input, [CreativeContext]$Context) {
        # Command dispatcher
        if ($Input -match "Enter") { return $this.EnterFlow($Input) }
        if ($Input -match "Exit") { return $this.ExitFlow() }
        if ($Input -match "Mood") { return $this.AnalyzeMood() }
        
        return [CreativeOutput]::new("Unknown Flow command")
    }

    [CreativeOutput] EnterFlow([string]$TaskInput) {
        $task = $TaskInput -replace "Enter", "" -replace "-Task", "" 
        $task = $task.Trim()
        if ([string]::IsNullOrEmpty($task)) { $task = "Deep Work" }

        $Global:IntentShellFlowState.IsActive = $true
        $Global:IntentShellFlowState.StartTime = Get-Date
        $Global:IntentShellFlowState.Task = $task
        
        # Store original prompt
        if (-not (Test-Path Function:\Global:Prompt_Original)) {
            Copy-Item Function:\prompt Function:\Global:Prompt_Original
        }
        
        # We can't define global functions inside a class method easily in PS5 classes
        # So we rely on the wrapper function for the prompt switch
        
        return [CreativeOutput]::new("🌊 FLOW MODE ACTIVATED: $task")
    }

    [CreativeOutput] ExitFlow() {
        if (-not $Global:IntentShellFlowState.IsActive) {
            return [CreativeOutput]::new("Flow Mode is not active.")
        }
        
        $duration = (Get-Date) - $Global:IntentShellFlowState.StartTime
        $Global:IntentShellFlowState.IsActive = $false
        
        return [CreativeOutput]::new("🏁 FLOW SESSION COMPLETE`n   Task: $($Global:IntentShellFlowState.Task)`n   Duration: $($duration.ToString("hh\:mm\:ss"))")
    }

    [CreativeOutput] AnalyzeMood() {
        $recentErrors = $Global:Error | Select-Object -First 5
        $errorCount = $recentErrors.Count
        
        if ($errorCount -gt 3) {
            return [CreativeOutput]::new("🤔 Frustrated. (High error rate detected)")
        } else {
            return [CreativeOutput]::new("😊 Calm. (System healthy)")
        }
    }
}

# --- Wrappers ---

function Enter-FlowMode {
    [CmdletBinding()]
    param([string]$Task = "Deep Work")

    $mod = [FlowStateModule]::new()
    $out = $mod.EnterFlow($Task)
    
    Write-Host "`n$($out.Text)" -ForegroundColor Cyan
    Write-Host "   Notifications silenced. Output simplified. Good luck.`n" -ForegroundColor Gray

    # Set Minimalist Prompt (Global scope modification needs to happen here)
    function Global:prompt { "🌊 > " }
}

function Exit-FlowMode {
    [CmdletBinding()]
    param()

    $mod = [FlowStateModule]::new()
    $out = $mod.ExitFlow()
    
    # Restore Prompt
    if (Test-Path Function:\Global:Prompt_Original) {
        Copy-Item Function:\Global:Prompt_Original Function:\prompt
    }

    if ($out.Text -match "not active") {
        Write-Warning $out.Text
    } else {
        Write-Host "`n$($out.Text)" -ForegroundColor Green
        Write-Host "   Welcome back." -ForegroundColor Gray
    }
}

function Get-MoodAnalysis {
    [CmdletBinding()]
    param()
    
    $mod = [FlowStateModule]::new()
    $out = $mod.AnalyzeMood()
    
    if ($out.Text -match "Frustrated") {
        Write-Host "`n$($out.Text)" -ForegroundColor Yellow
        Write-Host "   Maybe take a break or try 'Invoke-RubberDuck'?" -ForegroundColor Gray
    } else {
        Write-Host "`n$($out.Text)" -ForegroundColor Green
    }
    return $out.Text
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([FlowStateModule]::new())
}

Export-ModuleMember -Function Enter-FlowMode, Exit-FlowMode, Get-MoodAnalysis
