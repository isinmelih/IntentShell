
# NoteManager Module
# Handles creating, listing, and deleting simple text-based reminders/notes.
# Storage: config/reminders.txt (Format: TIMESTAMP | CONTENT)

class NoteManagerModule : ISystemModule {
    [string] $Name = "NoteManagerModule"
    [string] $Description = "Manages simple text notes and reminders"
    [string] $StoragePath

    NoteManagerModule() {
        # Determine storage path relative to module location or user profile
        # Defaulting to a safe user-writable location
        $configDir = Join-Path $env:USERPROFILE "Documents\trae_projects\IntentShell\config"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        $this.StoragePath = Join-Path $configDir "reminders.txt"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Notes:Add" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Missing note content.") }
                    $content = $Plan.Arguments[0]
                    $this.AddNote($content)
                    return [ModuleResult]::new($true, "Note added: '$content'")
                }
                "Notes:List" {
                    $notes = $this.ListNotes()
                    if ($notes) {
                        return [ModuleResult]::new($true, $notes)
                    } else {
                        return [ModuleResult]::new($true, "No reminders found.")
                    }
                }
                "Notes:Delete" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Missing content to delete.") }
                    $target = $Plan.Arguments[0]
                    if ($this.DeleteNote($target)) {
                        return [ModuleResult]::new($true, "Deleted note matching: '$target'")
                    } else {
                        return [ModuleResult]::new($false, "No matching note found for: '$target'")
                    }
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' not supported.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input")
    }

    [void] AddNote([string]$Content) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
        $entry = "$timestamp | $Content"
        Add-Content -Path $this.StoragePath -Value $entry -Encoding UTF8
    }

    [string] ListNotes() {
        if (-not (Test-Path $this.StoragePath)) { return "" }
        $content = Get-Content -Path $this.StoragePath -Encoding UTF8
        return ($content -join "`n")
    }

    [bool] DeleteNote([string]$Pattern) {
        if (-not (Test-Path $this.StoragePath)) { return $false }
        
        $lines = Get-Content -Path $this.StoragePath -Encoding UTF8
        $newLines = @()
        $found = $false

        foreach ($line in $lines) {
            # Check if line content (after timestamp) matches pattern
            # Line format: TIMESTAMP | CONTENT
            $parts = $line -split '\|', 2
            if ($parts.Count -eq 2) {
                $noteContent = $parts[1].Trim()
                if ($noteContent -match [regex]::Escape($Pattern)) {
                    $found = $true
                    continue # Skip this line (delete it)
                }
            }
            $newLines += $line
        }

        if ($found) {
            Set-Content -Path $this.StoragePath -Value $newLines -Encoding UTF8
            return $true
        }
        return $false
    }
}

function Add-Note {
    param([string]$Content)
    $mod = [NoteManagerModule]::new()
    $mod.AddNote($Content)
    Write-Output "✅ Reminder saved."
}

function Get-Notes {
    $mod = [NoteManagerModule]::new()
    $notes = $mod.ListNotes()
    if (-not [string]::IsNullOrWhiteSpace($notes)) {
        Write-Output "`n📅 YOUR REMINDERS:`n-------------------"
        Write-Output $notes
        Write-Output "-------------------"
    } else {
        Write-Output "📭 No reminders found."
    }
}

function Remove-Note {
    param([string]$Content)
    $mod = [NoteManagerModule]::new()
    if ($mod.DeleteNote($Content)) {
        Write-Output "🗑️ Note deleted."
    } else {
        Write-Warning "No note found matching '$Content'."
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([NoteManagerModule]::new())
}

Export-ModuleMember -Function Add-Note, Get-Notes, Remove-Note