# CreativeStudio.psm1
# A suite of creativity and brainstorming tools implementing the CreativeCore interface
# Requires CreativeCore.psm1 to be loaded first

using module .\CreativeCore.psm1
using module .\SystemCore.psm1

# --- Stateless Modules ---

class PerspectiveShiftModule : StatelessCreativeModule {
    PerspectiveShiftModule() : base("PerspectiveShift") {}

    [CreativeOutput] Run([string]$Input, [CreativeContext]$Context) {
        $parts = $Input -split "-Persona"
        $problem = $parts[0].Trim()
        $persona = if ($parts.Length -gt 1) { $parts[1].Trim() } else { "Hacker" }
        
        $templates = @{
            "Hacker" = "How can I break this? Where are the inputs untrusted? What if I send garbage data? Is there a race condition?"
            "ProductManager" = "Does this add value to the user? Is it too complex? Can we ship an MVP of this today? What is the metric?"
            "Academic" = "Is this theoretically sound? What is the Big-O complexity? Is there a formal proof for this logic? References?"
            "User" = "I don't care how it works, I just want to click the button. Why is it slow? Where is the 'Undo'?"
            "Investor" = "How does this make money? Is it scalable? What is the moat? Why are we building this instead of buying?"
        }

        if (-not $templates.ContainsKey($persona)) {
            $persona = "Hacker"
        }

        $outText = "🎩 Perspective Shift: $Persona`n" +
                   "   Problem: $problem`n" +
                   "   ----------------------------------------`n" +
                   "   $($templates[$persona])"
                   
        return [CreativeOutput]::new($outText)
    }
}

class WhatIfConstraintModule : StatelessCreativeModule {
    WhatIfConstraintModule() : base("WhatIfConstraint") {}

    [CreativeOutput] Run([string]$Input, [CreativeContext]$Context) {
        $constraints = @(
            "No Internet Access",
            "Read-Only Filesystem",
            "10MB Memory Limit",
            "Single Threaded Only",
            "No Database allowed (Flat files only)",
            "Must support IE6",
            "CLI Only (No GUI)",
            "User is blind (Accessibility first)"
        )
        $constraint = $constraints | Get-Random

        $outText = "⛓️  What-If Constraint`n" +
                   "   Problem: $Input`n" +
                   "   Constraint: $constraint`n" +
                   "   ----------------------------------------`n" +
                   "   How would you solve it now?"
                   
        return [CreativeOutput]::new($outText)
    }
}

# --- Hybrid / Stateful Modules ---

class SerendipityModule : StatefulCreativeModule {
    SerendipityModule() : base("Serendipity", "Project") {}

    [CreativeOutput] Run([string]$Input, [CreativeContext]$Context) {
        # Hybrid: Uses State (Ideas) OR Stateless (Files)
        $randomType = Get-Random -InputObject @("File", "Idea")
        
        $outText = ""
        
        if ($randomType -eq "File") {
            $files = Get-ChildItem -Path $Context.Path -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "node_modules|\.git|venv|__pycache__" }
            if ($files) {
                $file = $files | Get-Random
                $preview = Get-Content $file.FullName -TotalCount 5 | Out-String
                $outText = "🎲 Serendipity (File):`n" +
                           "   Do you remember this file?`n" +
                           "   Path: $($file.FullName)`n" +
                           "   Last Modified: $($file.LastWriteTime)`n" +
                           "   ----------------`n" +
                           "$preview"
            } else {
                $outText = "🎲 Serendipity: No suitable files found in project."
            }
        }
        else {
            # Try to load ideas if available
            # We assume IdeaScratchpad manages the idea storage, but here we can try to read it or use our own state
            # Ideally Serendipity should read the "IdeaScratchpad" state. 
            # For this implementation, we'll keep it simple and look for the standard idea file manually if state is empty
            
            # NOTE: In a real plugin system, we'd query the IdeaScratchpad module.
            $ideaPath = "$env:USERPROFILE\.intentshell\ideas.json"
            if (Test-Path $ideaPath) {
                $ideas = Get-Content $ideaPath -Raw | ConvertFrom-Json
                if ($ideas) {
                    if ($ideas -isnot [Array]) { $ideas = @($ideas) }
                    $idea = $ideas | Get-Random
                    $outText = "🎲 Serendipity (Idea):`n" +
                               "   From your Second Brain:`n" +
                               "   $($idea.Content)`n" +
                               "   (Project: $($idea.Project))"
                }
            }
            
            if ([string]::IsNullOrEmpty($outText)) {
                 $outText = "🎲 Serendipity: No ideas found yet. Try 'idea' command first!"
            }
        }
        
        return [CreativeOutput]::new($outText)
    }
}

# --- Function Wrappers for CLI ---

function Invoke-PerspectiveShift {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$Problem,
        [string]$Persona = "Hacker"
    )
    $mod = [PerspectiveShiftModule]::new()
    $inputStr = "$Problem -Persona $Persona"
    $res = Invoke-CreativeModule -Module $mod -InputText $inputStr
    Write-Host $res.Text
}

function Invoke-WhatIfConstraint {
    [CmdletBinding()]
    param([string]$Problem)
    $mod = [WhatIfConstraintModule]::new()
    $res = Invoke-CreativeModule -Module $mod -InputText $Problem
    Write-Host $res.Text
}

function Invoke-Serendipity {
    [CmdletBinding()]
    param()
    $mod = [SerendipityModule]::new()
    $res = Invoke-CreativeModule -Module $mod -InputText ""
    Write-Host $res.Text
}

# Rubber Duck needs special handling as it's interactive loop
function Invoke-RubberDuck {
    [CmdletBinding()]
    param()
    Write-Host "`n🦆 Rubber Duck is listening. (Type 'exit' or 'thanks' to finish)" -ForegroundColor Yellow
    
    # Simple loop for now, could be a Stateful Module that keeps conversation history
    while ($true) {
        $input = Read-Host "You"
        if ($input -match "exit|thanks|bye|done") {
            Write-Host "🦆 Happy coding! Quack." -ForegroundColor Yellow
            break
        }
        Start-Sleep -Milliseconds 500
        $replies = @("I see.", "Why?", "What if?", "Go on.")
        $reply = $replies | Get-Random
        Write-Host "Duck: $reply" -ForegroundColor Yellow
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([PerspectiveShiftModule]::new())
    [SystemCore]::RegisterModule([WhatIfConstraintModule]::new())
    [SystemCore]::RegisterModule([SerendipityModule]::new())
}

Export-ModuleMember -Function Invoke-PerspectiveShift, Invoke-WhatIfConstraint, Invoke-Serendipity, Invoke-RubberDuck