# PathResolution.psm1
# Phase 21: Path Resolution Module (PRM)
# Refactored for SystemCore Architecture

using module .\SystemCore.psm1

# Ensure SystemCore is loaded for types
# (In a real scenario, we might want a safer check, but session loader handles this)

class ExecutableSpec {
    [string]$AbsolutePath
    [string[]]$Args
    [string]$WorkingDirectory
    [hashtable]$EnvOverrides
    [string]$Source # PATH, PROJECT, ABSOLUTE, ALIAS, ENV
    [string]$Status # OK, ERROR, AMBIGUOUS
    [string]$ResolutionError
    [string]$OriginalHint

    ExecutableSpec() {
        $this.Args = @()
        $this.EnvOverrides = @{}
        $this.Status = "ERROR"
    }
}

# ---------------------------------------------------------
# SystemCore Integration
# ---------------------------------------------------------

class PathResolutionModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies

    PathResolutionModule() {
        $this.Name = "PathResolution"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['filesystem'] = 'read'
        $this.Capabilities['env'] = 'read'
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        # InputData is expected to be ExecutionPlan or a string
        $command = ""
        $args = @()

        if ($InputData -is [ExecutionPlan]) {
            $command = $InputData.Executable
            $args = $InputData.Args
        }
        elseif ($InputData -is [string]) {
            $command = $InputData
        }
        else {
            return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan or String")
        }

        # Use the internal logic
        $spec = $this.ResolveInternal($command, $args, $Context)

        if ($spec.Status -eq "OK") {
            # Update the Plan if passed
            if ($InputData -is [ExecutionPlan]) {
                $InputData.Executable = $spec.AbsolutePath
                # If resolution changed args (e.g. alias), update them? 
                # For now, we trust resolution found the path.
            }
            return [ModuleResult]::new($true, "Resolved to: $($spec.AbsolutePath)")
        }
        else {
            return [ModuleResult]::new($false, "Path Resolution Failed: $($spec.ResolutionError)")
        }
    }

    [ExecutableSpec] ResolveInternal([string]$CommandHint, [string[]]$Arguments, [SystemContext]$Context) {
        $spec = [ExecutableSpec]::new()
        $spec.OriginalHint = $CommandHint
        $spec.Args = $Arguments
        $spec.WorkingDirectory = $Context.ProjectRoot

        # 1. Handle Alias (PowerShell specific)
        if (Test-Path "Alias:\$CommandHint") {
            try {
                $alias = Get-Alias -Name $CommandHint -ErrorAction Stop
                $spec.Source = "ALIAS"
                $CommandHint = $alias.Definition
            }
            catch {}
        }

        # 1.5. Handle Tilde (~) Expansion
        if ($CommandHint.StartsWith("~")) {
            $homeDir = [System.Environment]::GetFolderPath('UserProfile')
            $CommandHint = $CommandHint -replace "^~", $homeDir
        }
        
        # 1.6. Clean up Double Backslashes (Cosmetic/Safety)
        if ($CommandHint -match "\\\\") {
            # Replace double backslashes with single, except for UNC paths (starting with \\)
            if ($CommandHint.StartsWith("\\")) {
                 # UNC Path: preserve start, fix rest
                 $uncRoot = $CommandHint.Substring(0, 2)
                 $rest = $CommandHint.Substring(2) -replace "\\+", "\"
                 $CommandHint = $uncRoot + $rest
            } else {
                 $CommandHint = $CommandHint -replace "\\+", "\"
            }
        }

        # 2. Check for Absolute or Explicit Relative Path
        if ($CommandHint -match "[\\/]") {
            # Fix relative path against ProjectRoot (Context)
            $potentialPath = $CommandHint
            if (-not [System.IO.Path]::IsPathRooted($CommandHint)) {
                $potentialPath = Join-Path $Context.ProjectRoot $CommandHint
            }

            if (Test-Path $potentialPath -PathType Leaf) {
                $spec.AbsolutePath = $potentialPath
                $spec.Status = "OK"
                $spec.Source = if ($spec.Source) { $spec.Source } else { "ABSOLUTE" }
                return $spec
            }
        }

        # 3. Project Context Lookup
        $projectPaths = @(".", "bin", "scripts", "tools", "node_modules\.bin", "venv\Scripts")
        foreach ($subPath in $projectPaths) {
            $candidateDir = Join-Path $Context.ProjectRoot $subPath
            if (Test-Path $candidateDir) {
                $extensions = $env:PATHEXT -split ";"
                $extensions += "" 
                foreach ($ext in $extensions) {
                    $candidateFile = Join-Path $candidateDir "$CommandHint$ext"
                    if (Test-Path $candidateFile -PathType Leaf) {
                        $spec.AbsolutePath = $candidateFile
                        $spec.Status = "OK"
                        $spec.Source = "PROJECT"
                        return $spec
                    }
                }
            }
        }

        # 4. PATH Environment Lookup
        try {
            $cmdInfo = Get-Command -Name $CommandHint -Type Application -ErrorAction Stop
            if ($cmdInfo) {
                $spec.AbsolutePath = $cmdInfo.Source
                $spec.Status = "OK"
                $spec.Source = "PATH"
                return $spec
            }
        }
        catch {}

        # 5. Fallback
        $spec.Status = "ERROR"
        $spec.ResolutionError = "Command '$CommandHint' not found in Project Context or System PATH."
        return $spec
    }
}

# ---------------------------------------------------------
# Standalone Functions (CLI Wrappers)
# ---------------------------------------------------------

function Resolve-Executable {
    [CmdletBinding()]
    [OutputType([ExecutableSpec])]
    param(
        [Parameter(Mandatory=$true)] [string]$CommandHint,
        [Parameter(ValueFromRemainingArguments=$true)] [string[]]$Arguments
    )
    
    # Create a temporary context for standalone use
    $ctx = [SystemContext]::new()
    $module = [SystemCore]::GetModule("PathResolution")
    return $module.ResolveInternal($CommandHint, $Arguments, $ctx)
}

function Get-PathResolutionDebug {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)] [string]$Command)
    
    $spec = Resolve-Executable -CommandHint $Command
    
    $props = [ordered]@{
        'Input' = $Command
        'Status' = $spec.Status
        'Source' = $spec.Source
        'Path'   = $spec.AbsolutePath
    }
    
    if ($spec.Status -ne 'OK') {
        $props['Error'] = $spec.ResolutionError
    }
    
    [PSCustomObject]$props | Format-List
}

# Register with SystemCore
[SystemCore]::RegisterModule([PathResolutionModule]::new())

Export-ModuleMember -Function Resolve-Executable, Get-PathResolutionDebug
