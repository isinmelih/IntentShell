using module .\SystemCore.psm1

# IntentShell Context Awareness Module
# Provides situational awareness to the AI Engine

function Get-CurrentContext {
    <#
    .SYNOPSIS
    Gathers environmental context to inform intent resolution.
    #>
    [CmdletBinding()]
    param()
    
    $path = Get-Location
    $context = @{
        Path = $path.Path
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        User = $env:USERNAME
        IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # 1. Project Detection
    $context.Project = @{
        Type = "Unknown"
        Frameworks = @()
    }
    
    if (Test-Path "$path\.git") {
        $context.Project.IsGitRepo = $true
        try {
            $branch = git branch --show-current 2>$null
            $context.Project.GitBranch = $branch
        } catch {}
    } else {
        $context.Project.IsGitRepo = $false
    }
    
    # Heuristics for Project Type
    if (Test-Path "$path\package.json") { 
        $context.Project.Type = "NodeJS"
        $context.Project.Frameworks += "NPM"
    }
    if (Test-Path "$path\requirements.txt") { 
        $context.Project.Type = "Python"
        $context.Project.Frameworks += "Pip"
    }
    if (Test-Path "$path\pyproject.toml") { 
        $context.Project.Type = "Python" 
        $context.Project.Frameworks += "Poetry/Flit"
    }
    if (Test-Path "$path\Cargo.toml") { 
        $context.Project.Type = "Rust" 
        $context.Project.Frameworks += "Cargo"
    }
    if (Test-Path "$path\pom.xml") { 
        $context.Project.Type = "Java" 
        $context.Project.Frameworks += "Maven"
    }
    if (Get-ChildItem "$path" -Filter "*.sln" -ErrorAction SilentlyContinue) {
        $context.Project.Type = "DotNet"
        $context.Project.Frameworks += "MSBuild"
    }

    # 2. Time/Mode Awareness
    $hour = (Get-Date).Hour
    $context.Mode = "Standard"
    if ($hour -ge 22 -or $hour -lt 6) {
        $context.Mode = "Night/Focus" # Suggest quieter output or dark mode themes
    }
    
    return [PSCustomObject]$context
}

class ContextAwarenessModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    ContextAwarenessModule() {
        $this.Name = "ContextAwareness"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'Read'
        $this.Description = "Situational Awareness Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Context:Get" {
                    $res = Get-CurrentContext
                    $mr = [ModuleResult]::new($true, "Context Retrieved")
                    $mr.Data = $res
                    return $mr
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by ContextAwarenessModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([ContextAwarenessModule]::new())
}

Export-ModuleMember -Function Get-CurrentContext
