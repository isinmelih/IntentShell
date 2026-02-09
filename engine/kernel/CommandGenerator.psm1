
# IntentShell Command Generator
# Converts Intent objects into safe PowerShell commands
# Uses AST for safety validation of AI-generated code

function Test-ScriptSafety {
    param([string]$Script)
    
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Script, [ref]$tokens, [ref]$errors)
    
    # 1. Denylist of dangerous commands/methods
    $denylist = @(
        "Invoke-Expression", "iex", 
        "Start-Process", # Only allow via wrapper if needed, but for now flag it
        "System.Reflection", "Runtime.InteropServices",
        "Reflection.Assembly", "Add-Type", "Emit", # Dynamic code compilation block
        "DownloadString", "DownloadFile" # Block unrestricted web downloads
    )
    
    foreach ($token in $tokens) {
        if ($token.Text -in $denylist) {
            Write-Warning "Blocked dangerous token: $($token.Text)"
            return $false
        }
    }
    
    # 2. Check for suspicious .NET calls
    if ($Script -match "\[.*\]::") {
        # Allow only safe types (Math, Environment, etc.)
        if ($Script -notmatch "\[Math\]|\[Environment\]|\[System.IO.Path\]") {
             Write-Warning "Blocked potentially unsafe .NET usage."
             return $false
        }
    }
    
    return $true
}

function ConvertTo-SafePowerShellCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Intent
    )
    
    # 0. Protocol Check
    if ($null -eq $Intent.protocol_version -or $Intent.protocol_version -ne "intent-v1") {
        Write-Warning "Protocol Mismatch: Expected 'intent-v1', got '$($Intent.protocol_version)'. Rejecting execution."
        throw "Security Error: Invalid or missing protocol version."
    }

    # 1. Priority: AI-Generated Command (if available and safe)
    if ($Intent.generated_command) {
        $cmd = $Intent.generated_command
        if (Test-ScriptSafety -Script $cmd) {
            Write-Verbose "Using AI-generated command (Safety Check Passed)."
            return $cmd
        } else {
            Write-Warning "AI-generated command failed safety check. Falling back to heuristic generation."
        }
    }
    
    # 2. Fallback: Manual Construction (The "Safe Mode")
    $action = $Intent.action
    $target = $Intent.target
    
    if ($target -eq "desktop") { $target = [Environment]::GetFolderPath("Desktop") }
    
    switch ($action) {
        "list" { return "Get-ChildItem -Path '$target'" }
        "delete" { 
            $cmd = "Remove-Item -Path '$target' -Force"
            if ($Intent.recursive) { $cmd += " -Recurse" }
            return "$cmd -ErrorAction Stop"
        }
        "create_file" { return "New-Item -Path '$target' -ItemType File -Force" }
        "create_folder" { return "New-Item -Path '$target' -ItemType Directory -Force" }
        default {
            throw "Could not generate safe command for action '$action' and AI command was rejected/missing."
        }
    }
}

Export-ModuleMember -Function ConvertTo-SafePowerShellCommand
