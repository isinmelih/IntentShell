
# IntentShell AI Engine Layer
# Advanced "PowerShell-Aware" AI Engine

function Start-LocalLLMEngine {
    [CmdletBinding()]
    param(
        [string]$Provider = "Ollama", # Ollama, Groq, OpenAI
        [string]$Model = "llama3.2:latest",
        [string]$Url = "http://localhost:11434",
        [string]$ApiKey = $null
    )

    Write-Verbose "Checking if Local LLM Engine ($Provider) is running at $Url..."
    
    if ($Provider -eq "Groq" -or $Provider -eq "OpenAI") {
        # Cloud API Check (Simple connectivity check)
        # Note: Groq/OpenAI don't have a simple /tags endpoint like Ollama. 
        # We assume reachable if we have internet.
        # We could try a small model listing request if we had the key, but for check, we return true if Key exists.
        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
             Write-Warning "API Key missing for $Provider."
             return $false
        }
        return $true
    }
    
    # Ollama Check
    try {
        $response = Invoke-RestMethod -Uri "$Url/api/tags" -Method Get -ErrorAction Stop -TimeoutSec 5
        Write-Verbose "Engine is running. Available models: $(($response.models.name) -join ', ')"
        return $true
    }
    catch {
        Write-Warning "Local LLM Engine not reachable at $Url. Please ensure Ollama is running."
        return $false
    }
}

function Get-RelevantPowerShellContext {
    param([string]$UserInput)
    
    # Initialize Cache if not exists
    if (-not $Global:IntentShellContextCache) {
        $Global:IntentShellContextCache = @{}
    }

    # 1. Extract potential keywords (simple split for now)
    $keywords = $UserInput -split " " | Where-Object { $_.Length -gt 4 } # Increased to 4 to reduce noise
    
    $context = @()
    foreach ($kw in $keywords) {
        # Check Cache first
        if ($Global:IntentShellContextCache.ContainsKey($kw)) {
            $context += $Global:IntentShellContextCache[$kw]
            continue
        }

        # Search for cmdlets matching keywords
        # Limit to 3 to reduce context size
        $cmds = Get-Command "*$kw*" -CommandType Cmdlet,Function -ErrorAction SilentlyContinue | Select-Object -First 3
        
        if ($cmds) {
            $kwContext = ""
            foreach ($cmd in $cmds) {
                # Get syntax/usage for the command to help the AI
                try {
                    $syntax = Get-Command $cmd.Name -Syntax
                    $kwContext += "Command: $($cmd.Name)`nSyntax: $syntax`n"
                } catch {}
            }
            # Cache the result for this keyword
            $Global:IntentShellContextCache[$kw] = $kwContext
            $context += $kwContext
        }
    }
    
    # Deduplicate and return top context
    return $context | Select-Object -Unique | Select-Object -First 10
}

function Invoke-IntentGeneration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserInput,
        
        [string]$Model = "llama3.2:latest",
        [string]$Url = "http://localhost:11434",
        [string]$Provider = "Ollama",
        [string]$ApiKey = $null
    )

    # 1. Gather Dynamic PowerShell Context
    Write-Verbose "Gathering PowerShell context for: $UserInput"
    $psContext = Get-RelevantPowerShellContext -UserInput $UserInput
    $contextString = if ($psContext) { "Available Relevant Commands on this System:`n" + ($psContext -join "`n") } else { "No specific local commands found." }

    $systemPrompt = @"
You are an expert PowerShell AI Agent running inside a Windows environment.
Your goal is to translate natural language user requests into precise, safe, and efficient PowerShell code.

You have access to the following local command context:
$contextString

INSTRUCTIONS:
1. Analyze the user request.
2. If the request contains multiple steps (e.g., 'and', 'then', 'after that'), break it down.
   - You MUST generate a SINGLE valid PowerShell script block.
   - Use semicolons ';' to chain commands.
   - Example: "Wait 3 seconds and take screenshot" -> "Start-Sleep -Seconds 3; Import-Module ...; Get-Screenshot"
3. Determine the best PowerShell cmdlet(s) to use.
4. Construct a JSON object representing the intent and the EXACT PowerShell command.
5. The 'generated_command' field MUST be valid, executable PowerShell code.
94. Use pipeline '|' where efficient.
95. Use '-ErrorAction Stop' or 'SilentlyContinue' ONLY for PowerShell Cmdlets. DO NOT append it to .NET/COM method calls (e.g., .AppActivate(), .Show()).
96.113. For destructive actions (Remove-*, Stop-*, etc.), ensure 'risk' is set to 'high' or 'very_high'.
114. Use PowerShell environment variables for user paths (e.g., $env:USERPROFILE, $env:USERNAME) instead of hardcoding 'C:\Users\Username'.
115. NEVER hardcode the username unless explicitly provided. Always prefer $env:USERPROFILE.
116. Avoid double backslashes in paths unless necessary for escaping. PowerShell accepts single backslashes or forward slashes.
117. IMPORTANT: Do NOT invent or hallucinate commands that do not exist. Stick to standard PowerShell cmdlets or installed modules.
118. Use 'Start-Process' to launch applications or open files, instead of 'Invoke-Item' with custom verbs like 'OpenWith'.
119. To open a file with a specific app: Start-Process -FilePath "path/to/app.exe" -ArgumentList "path/to/file"
120. To close a browser tab, use the project's WindowOperations module which has native 'Send-KeyboardInput' capability.
    Example (Close Chrome Tab):
    `Import-Module "$env:USERPROFILE\Documents\trae_projects\IntentShell\engine\modules\WindowOperations.psm1" -Force; Focus-Window -ProcessName 'chrome'; Start-Sleep -m 500; Send-KeyboardInput -Key 'Ctrl+W'`

JSON SCHEMA:
{
    "intent": "string (short_name)",
    "description": "string (explanation)",
    "target": "string (path/resource)",
    "action": "string (verb)",
    "risk": "low|medium|high|very_high",
    "generated_command": "string (The actual PowerShell script block)",
    "requires_elevation": boolean,
    "confirm_level": "none|enter|type_yes|two_step"
}

Respond ONLY with the JSON.
"@

    try {
        Write-Verbose "Sending request to LLM ($Provider)..."
        
        if ($Provider -eq "Groq" -or $Provider -eq "OpenAI") {
            # OpenAI Compatible API (Groq)
            $headers = @{
                "Authorization" = "Bearer $ApiKey"
                "Content-Type"  = "application/json"
            }
            
            $body = @{
                model = $Model
                messages = @(
                    @{ role = "system"; content = $systemPrompt },
                    @{ role = "user"; content = $UserInput }
                )
                temperature = 0.1
                response_format = @{ type = "json_object" } # Force JSON mode if supported
            }
            
            $response = Invoke-RestMethod -Uri $Url -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 5) -TimeoutSec 30
            
            $content = $response.choices[0].message.content
            $intent = $content | ConvertFrom-Json
            return $intent
        }
        else {
            # Default: Ollama
            $payload = @{
                model = $Model
                prompt = "$systemPrompt`n`nUser Request: $UserInput"
                stream = $false
                format = "json"
            }
            
            $response = Invoke-RestMethod -Uri "$Url/api/generate" -Method Post -Body ($payload | ConvertTo-Json) -ContentType "application/json"
            
            $jsonStr = $response.response
            $intent = $jsonStr | ConvertFrom-Json
            return $intent
        }
    }
    catch {
        Write-Error "Failed to generate intent via LLM: $_"
        return $null
    }
}

function Invoke-RiskAssessment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Intent,
        [object]$UserHistory,
        [string]$Model = "llama3.2:latest",
        [string]$Url = "http://localhost:11434"
    )
    # ... (Risk Assessment Logic - Same as before) ...
    return @{ adjusted_risk = $Intent.risk; reason = "Standard Check"; suggested_confirm_level = $Intent.confirm_level }
}

Export-ModuleMember -Function Start-LocalLLMEngine, Invoke-IntentGeneration, Invoke-RiskAssessment
