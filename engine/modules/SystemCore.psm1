# SystemCore.psm1
# Phase 22: System Core (Execution Supervisor)
# The strict orchestrator that manages system modules, execution plans, and safety gates.

# ---------------------------------------------------------
# 1. Data Contracts
# ---------------------------------------------------------

enum ExecutionStatus {
    Planned
    Approved
    Executing
    Suspended
    Completed
    Failed
    RolledBack
    Blocked
}

class ExecutionPlan {
    [string]$Id
    [string]$OriginalIntent
    [string]$Executable
    [string[]]$Args
    [string]$WorkingDir
    [hashtable]$Env
    [string]$RiskLevel
    [string]$OriginModule
    [string[]]$PreChecks # List of check names
    [string[]]$PostHooks # List of hook names
    [bool]$IsApproved
    [ExecutionStatus]$Status
    [string]$BlockReason

    # Advanced Features
    [bool]$IsShadowRun
    [int]$ConfidenceScore
    [hashtable]$SimulationResults

    # Lifecycle Fields
    [datetime]$CreatedTime
    [datetime]$StartTime
    [datetime]$EndTime
    [hashtable]$ContextSnapshot

    ExecutionPlan() {
        $this.Id = [guid]::NewGuid().ToString()
        $this.Env = @{}
        $this.PreChecks = @()
        $this.PostHooks = @()
        $this.Status = [ExecutionStatus]::Planned
        $this.IsApproved = $false
        $this.RiskLevel = "Medium" # Default
        $this.CreatedTime = Get-Date
        $this.ContextSnapshot = @{}
        
        $this.IsShadowRun = $false
        $this.ConfidenceScore = 0
        $this.SimulationResults = @{}
    }
}

class SystemContext {
    [string]$ProjectRoot
    [string]$User
    [bool]$IsElevated
    [bool]$IsInteractive
    [string]$SessionId
    [string]$Mood # "Focus", "Creative", "Cautious", "Standard"

    SystemContext() {
        $this.ProjectRoot = (Get-Location).Path
        $this.User = $env:USERNAME
        $this.IsInteractive = $true # Simplified for now
        $this.Mood = "Standard"
        
        # Check elevation
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]$identity
        $this.IsElevated = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        
        $this.SessionId = [System.Diagnostics.Process]::GetCurrentProcess().Id.ToString()
    }
}

class ModuleResult {
    [bool]$Success
    [string]$Message
    [object]$Data
    [bool]$CriticalFailure

    ModuleResult([bool]$success, [string]$msg) {
        $this.Success = $success
        $this.Message = $msg
        $this.CriticalFailure = $false
    }
}

class PlanCandidate {
    [ExecutionPlan]$Plan
    [string]$SourceModule
    [string]$Rationale
    [int]$ConfidenceScore
    [string[]]$Pros
    [string[]]$Cons
    
    PlanCandidate([ExecutionPlan]$p) {
        $this.Plan = $p
        $this.Pros = @()
        $this.Cons = @()
    }
}

class GovernancePolicy {
    [hashtable]$PriorityMap
    [string]$ConflictRule
    
    GovernancePolicy() {
        $this.PriorityMap = @{
            "Safety" = 100
            "System" = 80
            "Creative" = 50
        }
        $this.ConflictRule = "SafetyAlwaysWins"
    }
}

# ---------------------------------------------------------
# 2. Module Interface
# ---------------------------------------------------------

class SystemModule {
    [string]$Name
    [hashtable]$Capabilities # 'filesystem': 'read', 'process': 'spawn' etc.
    [string[]]$Dependencies # Names of other modules

    SystemModule([string]$name) {
        $this.Name = $name
        $this.Capabilities = @{}
        $this.Dependencies = @()
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        return [ModuleResult]::new($false, "Not Implemented")
    }

    # Optional Rollback
    [void] Rollback([SystemContext]$Context) {
        # Default: Do nothing
    }
}

# ---------------------------------------------------------
# 3. System Core (Orchestrator)
# ---------------------------------------------------------

class SystemCore {
    static [hashtable]$Modules = @{}
    static [hashtable]$ExecutionHistory = @{} # ID -> ExecutionPlan
    static [SystemContext]$CurrentContext
    static [System.Collections.ArrayList]$DecisionHistory = [System.Collections.ArrayList]::new()
    static [bool]$ExperimentalKernelMode = $false

    static [void] Initialize() {
        [SystemCore]::CurrentContext = [SystemContext]::new()
        Write-Verbose "SystemCore Initialized with Context: User=$([SystemCore]::CurrentContext.User), Elevated=$([SystemCore]::CurrentContext.IsElevated)"
    }
    
    static [void] EnableExperimentalKernelMode() {
        [SystemCore]::ExperimentalKernelMode = $true
        Write-Host "[SystemCore] EXPERIMENTAL KERNEL MODE ENABLED" -ForegroundColor Red
        Write-Host "   This mode allows direct internal delegation and kernel driver access." -ForegroundColor Yellow
    }
    
    static [void] DisableExperimentalKernelMode() {
        [SystemCore]::ExperimentalKernelMode = $false
        Write-Host "[SystemCore] Experimental Kernel Mode Disabled" -ForegroundColor Green
    }

    static [hashtable] GetSelfReflection() {
        $reflection = @{
            'TotalDecisions' = [SystemCore]::DecisionHistory.Count
            'VetoCount' = ([SystemCore]::DecisionHistory | Where-Object { $_.Decision -eq 'BLOCKED' }).Count
            'ErrorCount' = ([SystemCore]::DecisionHistory | Where-Object { $_.Decision -eq 'FAILED' }).Count
            'AvgConfidence' = 0 # Placeholder
            'RecentTrends' = @{}
        }
        
        # Analyze last hour
        $recent = [SystemCore]::DecisionHistory | Where-Object { $_.Timestamp -gt (Get-Date).AddHours(-1) }
        if ($recent) {
            $reflection['RecentTrends']['Volume'] = $recent.Count
            $reflection['RecentTrends']['MostCommonOrigin'] = ($recent | Group-Object Origin | Sort-Object Count -Descending | Select-Object -First 1).Name
        }
        
        return $reflection
    }

    static [void] LogDecision([ExecutionPlan]$Plan, [string]$Decision, [string]$Reason) {
        $entry = @{
            Timestamp = Get-Date
            Id = $Plan.Id
            Intent = $Plan.OriginalIntent
            Origin = $Plan.OriginModule
            Decision = $Decision
            Reason = $Reason
            User = [SystemCore]::CurrentContext.User
        }
        [SystemCore]::DecisionHistory.Add($entry) | Out-Null
        
        # Also track in history
        if (-not [SystemCore]::ExecutionHistory.ContainsKey($Plan.Id)) {
            [SystemCore]::ExecutionHistory[$Plan.Id] = $Plan
        }
    }

    static [void] SnapshotContext([ExecutionPlan]$Plan) {
        # Capture environmental state for deterministic replay
        $Plan.ContextSnapshot['User'] = [SystemCore]::CurrentContext.User
        $Plan.ContextSnapshot['CWD'] = (Get-Location).Path
        $Plan.ContextSnapshot['Timestamp'] = Get-Date
        $Plan.ContextSnapshot['Elevated'] = [SystemCore]::CurrentContext.IsElevated
    }

    static [void] RegisterModule([object]$Module) {
        # Duck Typing Validation
        if (-not $Module.PSObject.Properties["Name"]) {
            throw "Invalid Module: Missing 'Name' property."
        }
        if (-not $Module.PSObject.Methods["Run"]) {
             throw "Invalid Module: Missing 'Run' method."
        }

        [SystemCore]::Modules[$Module.Name] = $Module
        Write-Verbose "Registered System Module: $($Module.Name)"
    }

    static [object] GetModule([string]$Name) {
        if ([SystemCore]::Modules.ContainsKey($Name)) {
            return [SystemCore]::Modules[$Name]
        }
        $msg = "Module '" + $Name + "' not found in SystemCore registry."
        throw $msg
    }

    # Main Orchestration Logic
    static [ExecutionPlan] CreatePlan([string]$Intent, [string]$Executable, [string[]]$Args) {
        $plan = [ExecutionPlan]::new()
        $plan.OriginalIntent = $Intent
        $plan.Executable = $Executable
        $plan.Args = $Args
        $plan.WorkingDir = [SystemCore]::CurrentContext.ProjectRoot
        
        # Default strict checks
        $plan.PreChecks += "PathResolution"
        $plan.PreChecks += "SafetyCheck"
        
        return $plan
    }

    static [int] CalculateConfidence([ExecutionPlan]$Plan) {
        if ($null -eq $Plan) {
            throw "ExecutionPlan is null."
        }

        [int]$score = 100

        switch ($Plan.RiskLevel) {
            "High"   { $score -= 40 }
            "Medium" { $score -= 10 }
        }

        if (-not $Plan.WorkingDir) {
            $score -= 50
        }
        elseif (-not (Test-Path $Plan.WorkingDir)) {
            $score -= 50
        }

        if ($Plan.Executable -and
            $Plan.Executable.StartsWith("Internal:") -and
            -not [SystemCore]::ExperimentalKernelMode) {
            $score = 0
        }

        if ($score -lt 0) {
            $score = 0
        }

        return $score
    }

    static [ModuleResult] RequestExecution([ExecutionPlan]$Plan) {
        if ($null -eq $Plan) {
            return [ModuleResult]::new($false, "ExecutionPlan is null.")
        }
        Write-Host "🏗️ SystemCore: Processing Execution Request for '$($Plan.OriginalIntent)' (Origin: $($Plan.OriginModule))" -ForegroundColor Cyan
        
        # Lifecycle: Snapshot Context
        [SystemCore]::SnapshotContext($Plan)

        # --- PHASE 0: Context Awareness (Mood) ---
        if ([SystemCore]::Modules.ContainsKey("ContextMood")) {
            try {
                $moodRes = [SystemCore]::Modules["ContextMood"].Run($null, [SystemCore]::CurrentContext)
                if ($moodRes.Success) {
                    [SystemCore]::CurrentContext.Mood = $moodRes.Message
                    Write-Host "🌤️ System Mood: $([SystemCore]::CurrentContext.Mood)" -ForegroundColor DarkCyan
                }
            } catch { Write-Verbose "ContextMood Check Failed: $_" }
        }

        # --- PHASE 1: Governance (SystemGovernor) ---
        if ([SystemCore]::Modules.ContainsKey("SystemGovernor")) {
            try {
                $govRes = [SystemCore]::Modules["SystemGovernor"].Run($Plan, [SystemCore]::CurrentContext)
                if (-not $govRes.Success) {
                     $Plan.Status = [ExecutionStatus]::Blocked
                     $Plan.BlockReason = $govRes.Message
                     [SystemCore]::LogDecision($Plan, "BLOCKED", $Plan.BlockReason)
                     Write-Host "🛑 SystemGovernor Veto: $($Plan.BlockReason)" -ForegroundColor Red
                     return $govRes
                }
            } catch { Write-Verbose "SystemGovernor Check Failed: $_" }
        }

        # Confidence Engine
        $Plan.ConfidenceScore = [SystemCore]::CalculateConfidence($Plan)
        $confColor = if ($Plan.ConfidenceScore -gt 70) { "Green" } else { "Yellow" }
        Write-Host "🧠 Confidence Score: $($Plan.ConfidenceScore)%" -ForegroundColor $confColor

        # Shadow Execution Logic
        if ($Plan.IsShadowRun) {
             Write-Host "👻 SHADOW MODE: Simulating execution..." -ForegroundColor DarkGray
             $Plan.Status = [ExecutionStatus]::Completed
             $Plan.SimulationResults['Confidence'] = $Plan.ConfidenceScore
             $Plan.SimulationResults['WouldBlock'] = $false
             $Plan.SimulationResults['Risk'] = $Plan.RiskLevel
             
             # Run PreChecks in Shadow Mode (Dry Run)
             foreach ($checkName in $Plan.PreChecks) {
                 if ([SystemCore]::Modules.ContainsKey($checkName)) {
                     $module = [SystemCore]::Modules[$checkName]
                     $res = $module.Run($Plan, [SystemCore]::CurrentContext)
                     if (-not $res.Success) {
                         $Plan.SimulationResults['WouldBlock'] = $true
                         $Plan.SimulationResults['BlockReason'] = $res.Message
                         return [ModuleResult]::new($true, "Shadow Run: Would Block ($($res.Message))")
                     }
                 }
             }
             
             return [ModuleResult]::new($true, "Shadow Execution Successful. Confidence: $($Plan.ConfidenceScore)%")
        }

        # Low Confidence Guard
        if ($Plan.ConfidenceScore -lt 40) {
            Write-Warning "[SystemCore] Low Confidence ($($Plan.ConfidenceScore)%). Execution paused for safety."
            # In a real shell, we might ask for confirmation here.
            # For now, we log it and proceed with caution or block.
            # Let's block for safety demonstration.
             $Plan.Status = [ExecutionStatus]::Blocked
             $Plan.BlockReason = "Confidence Score too low ($($Plan.ConfidenceScore)%)."
             [SystemCore]::LogDecision($Plan, "BLOCKED", $Plan.BlockReason)
             return [ModuleResult]::new($false, $Plan.BlockReason)
        }

        # Capability Gate Check
        if (-not [string]::IsNullOrEmpty($Plan.OriginModule)) {
            if ([SystemCore]::Modules.ContainsKey($Plan.OriginModule)) {
                $origin = [SystemCore]::Modules[$Plan.OriginModule]
                
                # Check if module has 'process' -> 'spawn' capability
                if ($origin.Capabilities['Process'] -ne 'Spawn' -and $origin.Capabilities['Process'] -ne 'All') {
                      $Plan.Status = [ExecutionStatus]::Blocked
                      $Plan.BlockReason = "Module '$($Plan.OriginModule)' lacks 'Process:Spawn' capability."
                      [SystemCore]::LogDecision($Plan, "BLOCKED", $Plan.BlockReason)
                      Write-Host "[SystemCore] Veto: $($Plan.BlockReason)" -ForegroundColor Red
                      Write-Host "-> Suggested Action: Grant 'Process:Spawn' capability to '$($Plan.OriginModule)' or use a proxy module." -ForegroundColor Yellow
                      return [ModuleResult]::new($false, $Plan.BlockReason)
                 }
             } else {
                 Write-Warning "SystemCore: Origin module '$($Plan.OriginModule)' is not registered. Proceeding with caution (Legacy Mode)."
                 [SystemCore]::LogDecision($Plan, "WARNING", "Unknown Origin: $($Plan.OriginModule)")
             }
         }
 
         # 1. Pre-Checks (Strict Order)
         foreach ($checkName in $Plan.PreChecks) {
             if ([SystemCore]::Modules.ContainsKey($checkName)) {
                $module = [SystemCore]::Modules[$checkName]
                Write-Host "   ├─ Running Check: $($module.Name)..." -ForegroundColor Gray
                
                # Input for check is the Plan itself
                 $result = $module.Run($Plan, [SystemCore]::CurrentContext)
                 
                 if (-not $result.Success) {
                     $Plan.Status = [ExecutionStatus]::Blocked
                     $Plan.BlockReason = "$($module.Name) Check Failed: $($result.Message)"
                     [SystemCore]::LogDecision($Plan, "BLOCKED", $Plan.BlockReason)
                     Write-Host "[PreCheck] Failed: $($Plan.BlockReason)" -ForegroundColor Red
                     Write-Host "-> Suggested Action: Review $($module.Name) requirements." -ForegroundColor Yellow
                     return [ModuleResult]::new($false, "Plan blocked by $($module.Name): $($result.Message)")
                 }
             }
             else {
                 [SystemCore]::LogDecision($Plan, "CRITICAL", "Missing Required Module: $checkName")
                 Write-Error "🛑 SystemCore Critical: Required check module '$checkName' is missing."
                 return [ModuleResult]::new($false, "Missing required module: $checkName")
             }
         }

         # 2. Execution (Actual)
         $Plan.Status = [ExecutionStatus]::Approved
         $Plan.StartTime = Get-Date

         # Internal Module Execution Handling (Delegation Pattern)
        if ($Plan.Executable -and $Plan.Executable.StartsWith("Internal:")) {
            # Gate: Experimental Kernel Mode Check
            if (-not [SystemCore]::ExperimentalKernelMode) {
                 $Plan.Status = [ExecutionStatus]::Blocked
                 $Plan.BlockReason = "Internal Delegation is disabled. Enable Experimental Kernel Mode to use this feature."
                 [SystemCore]::LogDecision($Plan, "BLOCKED", $Plan.BlockReason)
                 Write-Host "[SystemCore] Veto: Internal Delegation requires Experimental Kernel Mode." -ForegroundColor Red
                 return [ModuleResult]::new($false, $Plan.BlockReason)
            }

            Write-Host "   ├─ Delegating Internal Execution to '$($Plan.OriginModule)'..." -ForegroundColor Cyan
            
            if ([string]::IsNullOrEmpty($Plan.OriginModule)) {
                 $Plan.Status = [ExecutionStatus]::Failed
                 $Plan.EndTime = Get-Date
                 [SystemCore]::LogDecision($Plan, "FAILED", "Internal execution requires OriginModule.")
                 return [ModuleResult]::new($false, "Internal execution requires OriginModule.")
            }

            if ([SystemCore]::Modules.ContainsKey($Plan.OriginModule)) {
                 $module = [SystemCore]::Modules[$Plan.OriginModule]
                 try {
                     $Plan.Status = [ExecutionStatus]::Executing
                     # Delegate execution back to the module's Run method
                     $result = $module.Run($Plan, [SystemCore]::CurrentContext)
                     
                     $Plan.EndTime = Get-Date
                     if ($result.Success) {
                         $Plan.Status = [ExecutionStatus]::Completed
                         [SystemCore]::LogDecision($Plan, "EXECUTED", "Handled internally by $($Plan.OriginModule)")
                         
                         # DNA Learning Hook
                         if (Get-Command Update-IntentDNA -ErrorAction SilentlyContinue) {
                             Update-IntentDNA -Intent $Plan.OriginalIntent -OriginModule $Plan.OriginModule -Success $true
                         }

                         if ($result.Data) { Write-Output $result.Data }

                         # --- PHASE 4: Proactive Suggestions ---
                         if ([SystemCore]::Modules.ContainsKey("ProactiveSuggestion")) {
                              try {
                                  $suggRes = [SystemCore]::Modules["ProactiveSuggestion"].Run($Plan, [SystemCore]::CurrentContext)
                                  if ($suggRes.Success -and -not [string]::IsNullOrEmpty($suggRes.Message)) {
                                      Write-Host "`n$($suggRes.Message)" -ForegroundColor Magenta
                                  }
                              } catch {}
                         }

                         return $result
                     } else {
                         $Plan.Status = [ExecutionStatus]::Failed
                         [SystemCore]::LogDecision($Plan, "FAILED", "Internal Execution Failed: $($result.Message)")
                         
                         # DNA Learning Hook (Failure)
                         if (Get-Command Update-IntentDNA -ErrorAction SilentlyContinue) {
                             Update-IntentDNA -Intent $Plan.OriginalIntent -OriginModule $Plan.OriginModule -Success $false
                         }

                         return $result
                     }
                 } catch {
                      $Plan.EndTime = Get-Date
                      $Plan.Status = [ExecutionStatus]::Failed
                      [SystemCore]::LogDecision($Plan, "FAILED", "Internal Exception: $_")
                      return [ModuleResult]::new($false, "Internal Execution Exception: $_")
                 }
            } else {
                 $Plan.Status = [ExecutionStatus]::Failed
                 $Plan.EndTime = Get-Date
                 [SystemCore]::LogDecision($Plan, "FAILED", "Origin Module '$($Plan.OriginModule)' not found for Internal Execution.")
                 return [ModuleResult]::new($false, "Origin Module '$($Plan.OriginModule)' not found.")
            }
        }
        
        # Standard External Execution (ExecutionEngine)
        
        # Delegate to Kernel Execution Engine
        if (Get-Command Invoke-ExecutionPlan -ErrorAction SilentlyContinue) {
           try {
               Write-Host "   ├─ Delegating to ExecutionEngine..." -ForegroundColor Gray
               $Plan.Status = [ExecutionStatus]::Executing
               
               $output = Invoke-ExecutionPlan -Plan $Plan
               
               $Plan.EndTime = Get-Date
               $Plan.Status = [ExecutionStatus]::Completed
               
               # DNA Learning Hook
               if (Get-Command Update-IntentDNA -ErrorAction SilentlyContinue) {
                   Update-IntentDNA -Intent $Plan.OriginalIntent -OriginModule $Plan.OriginModule -Success $true
               }

               if ($output) {
                   Write-Host "$output"
               }

               # --- PHASE 4: Proactive Suggestions ---
               if ([SystemCore]::Modules.ContainsKey("ProactiveSuggestion")) {
                    try {
                        $suggRes = [SystemCore]::Modules["ProactiveSuggestion"].Run($Plan, [SystemCore]::CurrentContext)
                        if ($suggRes.Success -and -not [string]::IsNullOrEmpty($suggRes.Message)) {
                            Write-Host "`n$($suggRes.Message)" -ForegroundColor Magenta
                        }
                    } catch {}
               }

               [SystemCore]::LogDecision($Plan, "EXECUTED", "Handed off to ExecutionEngine")
               return [ModuleResult]::new($true, "Execution Completed")
           }
            catch {
                $Plan.EndTime = Get-Date
                $Plan.Status = [ExecutionStatus]::Failed
                [SystemCore]::LogDecision($Plan, "FAILED", $_.Exception.Message)
                
                # DNA Learning Hook (Failure)
                if (Get-Command Update-IntentDNA -ErrorAction SilentlyContinue) {
                    Update-IntentDNA -Intent $Plan.OriginalIntent -OriginModule $Plan.OriginModule -Success $false
                }

                return [ModuleResult]::new($false, "Execution Failed: $($_.Exception.Message)")
            }
        }
         else {
             $Plan.Status = [ExecutionStatus]::Failed
             $Plan.EndTime = Get-Date
             return [ModuleResult]::new($false, "ExecutionEngine (Invoke-ExecutionPlan) not loaded.")
         }
    }
}

# ---------------------------------------------------------
# 4. Helper Functions
# ---------------------------------------------------------

function Get-ExecutionHistory {
    <#
    .SYNOPSIS
    Returns the execution history from SystemCore.
    #>
    [CmdletBinding()]
    param()
    
    return [SystemCore]::ExecutionHistory.Values | Sort-Object CreatedTime -Descending
}

function Invoke-ReplayExecution {
    <#
    .SYNOPSIS
    Replays a past execution by creating a new plan with the same parameters.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id
    )
    
    if (-not [SystemCore]::ExecutionHistory.ContainsKey($Id)) {
        Write-Error "Execution ID '$Id' not found in history."
        return
    }
    
    $oldPlan = [SystemCore]::ExecutionHistory[$Id]
    Write-Host "[SystemCore] Replaying Execution: $($oldPlan.OriginalIntent) (Source: $($oldPlan.Id))" -ForegroundColor Cyan
    
    # Create new plan based on old one
    $newPlan = [SystemCore]::CreatePlan($oldPlan.OriginalIntent, $oldPlan.Executable, $oldPlan.Args)
    $newPlan.OriginModule = $oldPlan.OriginModule
    $newPlan.RiskLevel = $oldPlan.RiskLevel
    if ($oldPlan.Env) {
        $newPlan.Env = $oldPlan.Env.Clone()
    }
    
    # Time-Travel: Apply Overrides (if any)
    # Note: In a full implementation, we'd accept an -OverrideEnv parameter here.
    # For now, we assume the user modifies the plan before passing it if they were calling CreatePlan manually.
    # But for Replay, we are strictly replaying.
    # Let's add a hook for simulation if needed.
    
    # Execute
    return [SystemCore]::RequestExecution($newPlan)
}

function Invoke-ShadowExecution {
    <#
    .SYNOPSIS
    Simulates an execution plan without running it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ExecutionPlan]$Plan
    )
    
    $Plan.IsShadowRun = $true
    return [SystemCore]::RequestExecution($Plan)
}

function Get-SystemReflection {
    <#
    .SYNOPSIS
    Returns the system's self-awareness metrics.
    #>
    [CmdletBinding()]
    param()
    
    return [SystemCore]::GetSelfReflection()
}

# Auto-Initialize on Import
[SystemCore]::Initialize()

# Export-ModuleMember -Class SystemContext, ExecutionPlan, ModuleResult, SystemModule, SystemCore
Export-ModuleMember -Function *
