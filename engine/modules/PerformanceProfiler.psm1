using module .\SystemCore.psm1

# IntentShell Performance Profiler Module
# "time-why" - Execution Analysis
# Integrated with SystemCore

class PerformanceProfilerModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    PerformanceProfilerModule() {
        $this.Name = "PerformanceProfiler"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.Capabilities['System'] = 'Read'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
         return [ModuleResult]::new($false, "Not Implemented")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([PerformanceProfilerModule]::new())
}

function Invoke-WithPerformance {
    <#
    .SYNOPSIS
    Runs a command via SystemCore and analyzes performance bottlenecks.
    .DESCRIPTION
    Executes a command (via SystemCore) and provides a breakdown of where the time went.
    Distinguishes between CPU work, Disk I/O, and Wait states (Network/Sleep).
    .ALIAS
    time-why
    .EXAMPLE
    time-why "Start-Sleep -Seconds 2"
    .EXAMPLE
    time-why "Get-ChildItem -Recurse c:\windows"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Command
    )

    # 1. Capture Initial State
    $process = [System.Diagnostics.Process]::GetCurrentProcess()
    $startCpu = $process.TotalProcessorTime.TotalMilliseconds
    
    # Try to get IO counters
    try {
        $startIoCount = $process.ReadOperationCount + $process.WriteOperationCount + $process.OtherOperationCount
        $startIoBytes = $process.ReadTransferCount + $process.WriteTransferCount + $process.OtherTransferCount
    } catch {
        $startIoCount = 0
        $startIoBytes = 0
    }

    Write-Host "⏱️  Profiling execution of '$Command'..." -ForegroundColor Cyan

    # 2. Run Command via SystemCore
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
            # Parse command (Naive split for now)
            $parts = $Command -split "\s+"
            $exe = $parts[0]
            $argsList = if ($parts.Count -gt 1) { $parts[1..($parts.Count-1)] } else { @() }
            
            $plan = [SystemCore]::CreatePlan("Profile: $Command", $exe, $argsList)
            $plan.OriginModule = "PerformanceProfiler"
            $plan.RiskLevel = "Medium"
            
            $result = [SystemCore]::RequestExecution($plan)
            if (-not $result.Success) {
                Write-Error "Execution Blocked/Failed: $($result.Message)"
                return
            }
        } else {
            Write-Warning "SystemCore not loaded. Profiling legacy execution (UNSAFE)."
            Invoke-Expression $Command
        }
    }
    catch {
        Write-Error $_
    }
    finally {
        $sw.Stop()
        $process.Refresh() # Critical to get updated stats
        
        # 3. Capture End State
        $endCpu = $process.TotalProcessorTime.TotalMilliseconds
        
        try {
            $endIoCount = $process.ReadOperationCount + $process.WriteOperationCount + $process.OtherOperationCount
            $endIoBytes = $process.ReadTransferCount + $process.WriteTransferCount + $process.OtherTransferCount
        } catch {
            $endIoCount = 0
            $endIoBytes = 0
        }

        # 4. Calculate Deltas
        $wallTimeMs = $sw.Elapsed.TotalMilliseconds
        if ($wallTimeMs -eq 0) { $wallTimeMs = 1 } # Safety

        $cpuTimeMs = $endCpu - $startCpu
        # Cap CPU time at Wall time (multicore can exceed wall time, but for ratio calc we want to know saturation)
        # Actually, for single process, TotalProcessorTime sums all threads. 
        # So if > wallTime, it's CPU bound parallel.
        
        $ioCount = $endIoCount - $startIoCount
        $ioBytes = $endIoBytes - $startIoBytes
        
        # Heuristics
        $cpuRatio = $cpuTimeMs / $wallTimeMs
        $bottleneck = "Unknown"
        
        if ($cpuRatio -gt 0.8) {
            $bottleneck = "CPU Bound"
        } elseif ($ioCount -gt 1000 -or $ioBytes -gt 10MB) {
            $bottleneck = "I/O Bound (Disk/Network)"
        } elseif ($wallTimeMs -gt ($cpuTimeMs * 2)) {
            $bottleneck = "Wait/Network/Sleep"
        } else {
            $bottleneck = "Balanced"
        }

        Write-Host "`n📊 Performance Report" -ForegroundColor Green
        Write-Host "----------------------" -ForegroundColor Green
        Write-Host "Wall Time : $([math]::Round($wallTimeMs, 2)) ms"
        Write-Host "CPU Time  : $([math]::Round($cpuTimeMs, 2)) ms (Ratio: $([math]::Round($cpuRatio, 2)))"
        Write-Host "I/O Ops   : $ioCount"
        Write-Host "I/O Bytes : $([math]::Round($ioBytes / 1KB, 2)) KB"
        Write-Host "Verdict   : $bottleneck" -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Invoke-WithPerformance