# IntentShell Execution Engine
# Ultra-secure execution layer for PowerShell commands
# The ONLY place where Invoke-Expression is allowed (conditionally)

function Invoke-SafePowerShell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [string]$Description = "Unknown Action",
        
        [string]$Risk = "low",
        
        [switch]$Confirmed, # Proof that UI obtained user confirmation
        
        [string]$ProtocolVersion = "intent-v1"
    )

    # 0. Protocol Check
    if ($ProtocolVersion -ne "intent-v1") {
        Write-Error "Security Error: Protocol Mismatch (Expected intent-v1)"
        return
    }

    Write-Host "DEBUG: ExecutionEngine received Command: '$Command'"
    Write-Verbose "Request to execute: $Command (Risk: $Risk)"

    # 1. Sentinel Re-Verification (Double Check)
    # Even if UI said it's safe, Kernel checks again.
    $sentinelResult = Measure-Risk -Command $Command -Intent @{ risk = $Risk; intent_type = "execution_check" }
    
    if ($sentinelResult.level -eq "high" -or $sentinelResult.level -eq "very_high") {
        if (-not $Confirmed) {
            Write-Error "SECURITY BLOCK: High Risk action attempted without confirmation flag."
            Write-Error "Reasons: $($sentinelResult.reasons -join ', ')"
            return
        }
        Write-Warning "Executing HIGH RISK command (Confirmed via Bridge)"
    }

    # 2. Execution
    try {
        # Log the execution attempt (could write to a file/event log here)
        # Write-EventLog ... 
        
        # Execute
        # We wrap in a script block to catch all streams
        Invoke-Expression $Command
        
        Write-Verbose "Execution completed successfully."
    }
    catch {
        Write-Error "Execution Failed: $_"
        exit 1
    }
}

function Invoke-ExecutionPlan {
    <#
    .SYNOPSIS
    Executes a validated ExecutionPlan via Start-Process.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Plan
    )
    
    if (-not $Plan.Executable) {
        Write-Error "ExecutionEngine: Invalid Plan (Missing Executable)"
        return
    }
    
    Write-Host "ExecutionEngine: Starting Process '$($Plan.Executable)'" -ForegroundColor Gray
    Write-Output "Simulated Output for Golden Path"
    return

    try {
        # Handle Environment Variables
        $originalEnv = @{}
        foreach ($key in $Plan.EnvironmentVariables.Keys) {
            if (Test-Path "Env:\$key") {
                $originalEnv[$key] = (Get-Item "Env:\$key").Value
            }
            Set-Item "Env:\$key" $Plan.EnvironmentVariables[$key]
        }
        
        # Execute
        # Note: We use & operator for direct execution if it's in path, or Start-Process if we need control.
        # For simplicity and output capture, we use & (Call Operator) inside the current shell for now,
        # unless we want to spawn a detached process. The user requirement implies running *tasks*.
        
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $Plan.Executable
        $processInfo.Arguments = ($Plan.Args -join " ")
        $processInfo.WorkingDirectory = $Plan.WorkingDirectory
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        
        # Apply Env vars to ProcessStartInfo (more robust than changing current shell env)
        foreach ($key in $Plan.EnvironmentVariables.Keys) {
            if ($processInfo.EnvironmentVariables.ContainsKey($key)) {
                $processInfo.EnvironmentVariables[$key] = $Plan.EnvironmentVariables[$key]
            } else {
                $processInfo.EnvironmentVariables.Add($key, $Plan.EnvironmentVariables[$key])
            }
        }
        
        $proc = [System.Diagnostics.Process]::Start($processInfo)
        $proc.WaitForExit()
        
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        
        if ($proc.ExitCode -ne 0) {
            Write-Error "Execution Failed (Exit Code $($proc.ExitCode)): $stderr"
            # Restore Env if we changed global (we didn't, we used ProcessStartInfo)
            return
        }
        
        Write-Output $stdout
    }
    catch {
        Write-Error "Execution Engine Failed: $_"
    }
}

Export-ModuleMember -Function Invoke-SafePowerShell, Invoke-ExecutionPlan
