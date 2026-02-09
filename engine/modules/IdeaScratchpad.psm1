# IdeaScratchpad.psm1
# Second Brain implementation using StatefulCreativeModule
# Requires CreativeCore.psm1

using module .\CreativeCore.psm1
using module .\SystemCore.psm1

class IdeaScratchpadModule : StatefulCreativeModule {
    IdeaScratchpadModule() : base("IdeaScratchpad", "User") {} # User scope for global ideas

    [CreativeOutput] Run([string]$Input, [CreativeContext]$Context) {
        # Input format: "Content | Tags | Project" (simplified for parsing)
        # Or standard "Add" vs "Get" actions embedded in input string?
        # The base interface expects a single Run method.
        # For complex modules, we interpret the Input string as an intent or command.
        
        # NOTE: In this refactor, we are exposing standard PowerShell functions (Add-Idea, Get-Ideas)
        # that internally use this class to maintain the "Interface Contract" while keeping UX simple.
        
        return [CreativeOutput]::new("Use Add-Idea or Get-Ideas commands.")
    }

    [void] AddIdea([string]$Content, [string[]]$Tags, [string]$Project) {
        if (-not $this.State.ContainsKey('Ideas')) {
            $this.State['Ideas'] = @()
        }
        
        # Ensure it's an array list or similar for adding
        $ideasList = $this.State['Ideas']
        if ($ideasList -isnot [System.Collections.ArrayList]) {
            $ideasList = [System.Collections.ArrayList]::new([object[]]$ideasList)
        }

        $newIdea = [PSCustomObject]@{
            Id = [Guid]::NewGuid().ToString()
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Content = $Content
            Tags = $Tags
            Project = $Project
            Status = "New"
        }

        $ideasList.Add($newIdea) | Out-Null
        $this.State['Ideas'] = $ideasList
        $this.SaveState()
    }

    [array] GetIdeas([string]$Tag, [string]$Project) {
        if (-not $this.State.ContainsKey('Ideas')) { return @() }
        
        $ideas = $this.State['Ideas']
        if ($null -eq $ideas) { return @() }

        if ($Project) {
            $ideas = $ideas | Where-Object { $_.Project -eq $Project }
        }
        if ($Tag) {
            $ideas = $ideas | Where-Object { $_.Tags -contains $Tag }
        }
        return $ideas
    }
}

# --- Wrapper Functions ---

function Add-Idea {
    <#
    .SYNOPSIS
    Quickly saves a fleeting thought or idea.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Content,
        [string[]]$Tags = @(),
        [string]$Project = $(Split-Path -Leaf (Get-Location))
    )

    $mod = [IdeaScratchpadModule]::new()
    $mod.LoadState()
    $mod.AddIdea($Content, $Tags, $Project)
    Write-Host "💡 Idea saved to Second Brain!" -ForegroundColor Yellow
}

function Get-Ideas {
    <#
    .SYNOPSIS
    Lists saved ideas.
    #>
    [CmdletBinding()]
    param(
        [string]$Tag,
        [string]$Project,
        [switch]$All
    )

    $mod = [IdeaScratchpadModule]::new()
    $mod.LoadState()
    
    $filterProj = if (-not $All -and -not $Project) { Split-Path -Leaf (Get-Location) } else { $Project }
    
    $ideas = $mod.GetIdeas($Tag, $filterProj)
    $ideas | Format-Table -Property Timestamp, Project, Content, Tags -AutoSize
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([IdeaScratchpadModule]::new())
}

Export-ModuleMember -Function Add-Idea, Get-Ideas
