# CreativeCore.psm1
# Defines the Base Interfaces and Contracts for Creative Modules
# Now integrated with SystemCore

using module .\SystemCore.psm1

class CreativeContext {
    [string]$Project
    [string]$Path
    [string]$User
    [datetime]$Timestamp
    [hashtable]$Metadata

    CreativeContext() {
        $this.Path = (Get-Location).Path
        $this.Project = Split-Path -Leaf $this.Path
        $this.User = $env:USERNAME
        $this.Timestamp = Get-Date
        $this.Metadata = @{}
    }
}

class CreativeOutput {
    [string]$Text
    [string[]]$FollowUpQuestions
    [string[]]$SuggestedNextIntents
    [double]$Confidence
    [hashtable]$Metadata

    CreativeOutput([string]$text) {
        $this.Text = $text
        $this.FollowUpQuestions = @()
        $this.SuggestedNextIntents = @()
        $this.Confidence = 1.0
        $this.Metadata = @{}
    }
}

class CreativeModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [bool]$SupportsContext

    CreativeModule([string]$name) {
        $this.Name = $name
        $this.Capabilities = @{}
        $this.Dependencies = @()
        $this.SupportsContext = $true
        $this.Capabilities['Creative'] = 'All'
    }

    # The Creative Interface (to be overridden)
    [CreativeOutput] RunCreative([string]$Input, [CreativeContext]$Context) {
        return [CreativeOutput]::new("Not Implemented")
    }

    # Bridge to SystemCore
    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
             $plan = $InputData
             # Extract input from Plan (Intent or Args)
             $inputStr = $plan.OriginalIntent
             # If specific arguments provided, prefer them as the input payload
             if ($plan.Arguments.Count -gt 0) {
                 # Join args back to string for Creative modules which often take raw text
                 $inputStr = $plan.Arguments -join " "
             }
             
             $cContext = [CreativeContext]::new()
             # Map SystemContext details if needed
             $cContext.User = $Context.User
             
             try {
                 # Call the creative specific implementation
                 # Note: Subclasses currently implement Run([string], [CreativeContext])
                 # We need to make sure we call THAT overload.
                 # In PS Classes, we might need to cast or ensure signature match.
                 # Since subclasses override the Creative signature, we can call it.
                 # BUT: I renamed the base method to RunCreative to avoid confusion/shadowing issues.
                 # Subclasses in CreativeStudio.psm1 implement 'Run'.
                 # So I should probably call 'Run' with the creative signature.
                 
                 $cOut = $this.Run($inputStr, $cContext)
                 return [ModuleResult]::new($true, $cOut.Text)
             }
             catch {
                 return [ModuleResult]::new($false, "Creative Logic Failed: $_")
             }
        }
        return [ModuleResult]::new($false, "CreativeModule requires ExecutionPlan")
    }

    # Overload for Creative Subclasses (they override this)
    [CreativeOutput] Run([string]$Input, [CreativeContext]$Context) {
        return [CreativeOutput]::new("Not Implemented")
    }
}

class StatelessCreativeModule : CreativeModule {
    StatelessCreativeModule([string]$name) : base($name) {
    }
}

class StatefulCreativeModule : CreativeModule {
    [hashtable]$State
    [string]$StateScope # 'Project' or 'User' or 'Session'
    [string]$StatePath

    StatefulCreativeModule([string]$name, [string]$scope) : base($name) {
        $this.State = @{}
        $this.StateScope = $scope
        $this.InitializeStatePath()
    }

    [void] InitializeStatePath() {
        [string]$home = [Environment]::GetFolderPath("UserProfile")
        [string]$baseDir = Join-Path $home ".intentshell\state\$($this.Name)"

        if (-not (Test-Path $baseDir)) { 
            New-Item -ItemType Directory -Path $baseDir -Force | Out-Null 
        }
        
        if ($this.StateScope -eq 'Project') {
            # Simple hash of path to avoid invalid chars
            $projHash = (Get-Location).Path.GetHashCode().ToString("x") 
            $this.StatePath = "$baseDir\project_$projHash.json"
        }
        else {
            $this.StatePath = "$baseDir\user_global.json"
        }
    }

    [void] LoadState() {
        if ($this.StateScope -eq 'Session') { return } # Session state is memory only

        if (Test-Path $this.StatePath) {
            try {
                $json = Get-Content -Path $this.StatePath -Raw
                if (-not [string]::IsNullOrWhiteSpace($json)) {
                    $loaded = $json | ConvertFrom-Json
                    # Convert generic object back to hashtable if needed, or just use psobject
                    # For simplicity in PS classes, we often keep it as PSObject or cast specifically
                    # Here we assume State is flexible
                    $this.State = $loaded
                }
            }
            catch {
                Write-Warning "Failed to load state for $($this.Name): $_"
            }
        }
    }

    [void] SaveState() {
        if ($this.StateScope -eq 'Session') { return }

        try {
            $this.State | ConvertTo-Json -Depth 5 | Set-Content -Path $this.StatePath -Force
        }
        catch {
            Write-Warning "Failed to save state for $($this.Name): $_"
        }
    }

    [void] ClearState() {
        $this.State = @{}
        if ($this.StateScope -ne 'Session' -and (Test-Path $this.StatePath)) {
            Remove-Item $this.StatePath -Force
        }
    }
}

# Factory/Helper to make usage easy from CLI
function Invoke-CreativeModule {
    param(
        [CreativeModule]$Module,
        [string]$InputText
    )
    
    $ctx = [CreativeContext]::new()
    
    if ($Module -is [StatefulCreativeModule]) {
        $Module.LoadState()
    }
    
    $output = $Module.Run($InputText, $ctx)
    
    if ($Module -is [StatefulCreativeModule]) {
        $Module.SaveState()
    }
    
    return $output
}
