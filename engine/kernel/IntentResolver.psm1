
# IntentShell Intent Resolver
# Resolves user input to Intent JSON using Registry or AI Engine

function Get-ForensicIntent {
    param([string]$ProcessName)

    # Check Experimental Mode Status
    $isExperimental = $Global:IntentShellConfig.ExperimentalModeEnabled

    if ($isExperimental) {
        # Experimental Mode: Full Kernel/Forensic Scan
        $intentObj = @{
            intent = "forensic_analyze"
            description = "Analyze memory/path of process '$ProcessName' (Kernel-Assisted)"
            target = $ProcessName
            action = "inspect_kernel"
            risk = "medium"
            generated_command = "Import-Module '$PSScriptRoot\Forensics.psm1' -Force; Invoke-ForensicScan -ProcessName '$ProcessName'"
            confirm_level = "none"
        }
    } else {
        # Stable Mode: User-Mode Diagnostic Only
        $intentObj = @{
            intent = "diagnostic_scan"
            description = "Basic Diagnostic of '$ProcessName' (User Mode)"
            target = $ProcessName
            action = "inspect_user"
            risk = "low"
            generated_command = "Get-Process -Name '$ProcessName' -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, Path, StartTime, Handles, WorkingSet | Format-List; Write-Warning 'Deep Kernel Analysis is disabled in Stable Mode.'"
            confirm_level = "none"
        }
    }
    return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
}

function Resolve-Intent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserInput
    )
    
    # === PRE-PROCESS: Macro Expansion ===
    # Replace all #variable occurrences with their values BEFORE any logic.
    if ($UserInput -match '#(\S+)') {
        # Ensure MacroManager is loaded
        if (-not (Get-Command Get-MacroVariable -ErrorAction SilentlyContinue)) {
             Import-Module "$PSScriptRoot\..\modules\MacroManager.psm1" -Force -ErrorAction SilentlyContinue
        }

        if (Get-Command Get-MacroVariable -ErrorAction SilentlyContinue) {
            # Find all matches
            $matchesFound = [regex]::Matches($UserInput, '#(\w+)')
            foreach ($match in $matchesFound) {
                $macroName = $match.Groups[1].Value
                $expanded = Get-MacroVariable -Name $macroName
                
                if ($expanded) {
                    Write-Verbose "Expanding Macro: #$macroName -> $expanded"
                    # Replace #macroName with expanded value
                    $UserInput = $UserInput -replace "#$macroName\b", $expanded
                }
            }
        }
    }
    
    # Pattern: Define Macro Variable
    # "set macro zoom to Open C:..." or "define variable #zoom = Clean My Desktop"
    if ($UserInput -match '^(?:set|define|create)\s+(?:macro|variable)\s+#?(\S+)\s+(?:to|as|=)\s+(.+)$') {
        $name = $matches[1]
        $value = $matches[2]
        
        # Check for spaces in name (already handled by regex \S+, but double check)
        if ($name -match '\s') {
             return (@{
                intent = "error"
                description = "Macro names cannot contain spaces."
                risk = "low"
            } | ConvertTo-Json -Compress)
        }

        return (@{
            intent = "set_macro"
            description = "Define macro #$name = '$value'"
            target = "macro_manager"
            action = "set_variable"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\MacroManager.psm1' -Force; Set-MacroVariable -Name '$name' -Value '$value'"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }
    
    # 1. Check Registry (Mock check for now as we don't have full Python regex logic here yet)
    # Ideally, we should port 'COMMAND_REGISTRY' to PowerShell hash table in Registry.psm1
    $registryIntent = Get-RegisteredIntent -UserInput $UserInput
    if ($registryIntent) {
        # Convert hashtable to JSON compatible with Intent schema
        $intentObj = @{
            intent = $registryIntent.intent
            description = $registryIntent.description
            target = "system" # Default if not specified
            action = "run_registered"
            risk = $registryIntent.risk
            generated_command = $registryIntent.command_template # Simple template usage
            confirm_level = $registryIntent.confirm_level
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }
    
    # Pattern: Intent Chaining (Sequential Commands)
    # "wait 3 seconds and take screenshot", "create folder test and open it"
    # MOVED TO TOP (Code moved to line 62)
    # This block is kept here just for reference or fallback, but the logic is executed at the top.
    
    # 2. Check Legacy Patterns (Regex Heuristics)
    
    # Pattern: Timer with Notification (Sound + Popup)
    # "set a timer for 10 minutes", "10 dakikalık zamanlayıcı kur"
    if ($UserInput -match '(?:set|start|kur)\s+(?:a\s+)?(?:timer|zamanlay\u0131c\u0131)\s+(?:for\s+)?(\d+)\s*(?:seconds|secs|s|minutes|mins|m)') {
        $val = $matches[1]
        $unit = "Seconds"
        if ($UserInput -match 'minutes|mins|m\b') { $unit = "Minutes" }
        
        $seconds = if ($unit -eq "Minutes") { [int]$val * 60 } else { [int]$val }
        
        # We need a non-blocking background job or a blocking wait with notification.
        # Since IntentShell executes commands sequentially, a blocking wait is safer for now but will lock the shell.
        # To avoid locking, we use Start-Job (Background).
        
        $jobScript = "Start-Sleep -Seconds $seconds; [System.Console]::Beep(1000, 500); [System.Console]::Beep(1500, 500); Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Timer for $val $unit finished!', 'IntentShell Timer', 'OK', 'Information')"
        
        # Use encoded command to avoid quote escaping hell in Start-Job -ScriptBlock
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($jobScript)
        $encodedCommand = [Convert]::ToBase64String($bytes)
        
        # Display the command clearly to the user (not the encoded blob)
        # The generated command uses Start-Job for background execution
        $generatedCmd = "Start-Job -ScriptBlock { param(`$script); Invoke-Expression `$script } -ArgumentList `"$jobScript`" | Out-Null; Write-Host 'Timer started for $val $unit in background.' -ForegroundColor Green"
        
        $intentObj = @{
            intent = "set_timer"
            description = "Set timer for $val $unit (Sound + Popup)"
            target = "system_timer"
            action = "timer"
            risk = "low"
            generated_command = $generatedCmd
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Create File
    if ($UserInput -match '(?:create|new|make)\s+(?:a\s+)?(?:text\s+)?(?:file|dosya)\s+(?:called|named|with name)?\s*[\u0027\u0022\u2018\u2019]?(.+?)[\u0027\u0022\u2018\u2019]?\s+(?:on|in|at)\s+(?:the\s+)?(?:klas\u00F6r\u00FC|folder\s+|directory\s+|masa\u00FCst\u00FCndeki\s+|desktop\s+)?(.+)$') {
        $fileName = $matches[1]
        $location = $matches[2].Trim()
        
        # Smart Folder Resolution
        $basePath = "$env:USERPROFILE"
        if ($location -match 'Documents|Belgeler') { $basePath = "$env:USERPROFILE\Documents" }
        elseif ($location -match 'Downloads|Indirilenler') { $basePath = "$env:USERPROFILE\Downloads" }
        elseif ($location -match 'Desktop|Masa') { $basePath = "$env:USERPROFILE\Desktop" }
        elseif ($location -match 'Pictures|Resimler') { $basePath = "$env:USERPROFILE\Pictures" }
        else { $basePath = Join-Path $env:USERPROFILE $location }

        $fullPath = Join-Path $basePath $fileName

        $intentObj = @{
            intent = "create_file"
            description = "Create file '$fileName' in '$location'"
            target = $fullPath
            action = "create"
            risk = "low"
            generated_command = "New-Item -Path '$fullPath' -ItemType File -Force"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Open File / App (Explicit)
    # "open it", "open file.txt", "open chrome"
    # Added "open X" to match chained commands correctly.
    # The previous regex required "open file/app X", which failed for simple "open it".
    if ($UserInput -match '(?:open|run|start|launch|a\u00E7|b\u0061\u015F\u006C\u0061\u0074)\s+(?:the\s+)?(?:file|app|application|dosya|uygulama)?\s*[\u0027\u0022\u2018\u2019]?(.+?)[\u0027\u0022\u2018\u2019]?$') {
        $target = $matches[1].Trim()
        
        # If target is 'it' or 'that', we assume it's a context reference.
        # We generate a command using a placeholder variable that Chaining Logic will replace.
        if ($target -match '^(it|that|o|onu|bunu)$') {
             $intentObj = @{
                intent = "open_context"
                description = "Open the item from previous context"
                target = "context_item"
                action = "open"
                risk = "medium" # Medium because we don't know what it is yet
                generated_command = "Start-Process -FilePath `"`$target`"" # Placeholder that will be replaced by chaining logic
                confirm_level = "none"
            }
            return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
        }

        # Otherwise standard open
        $intentObj = @{
            intent = "open_file"
            description = "Open '$target'"
            target = $target
            action = "open"
            risk = "low"
            generated_command = "Start-Process -FilePath '$target'"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Intent Chaining (Sequential Commands)
    # "wait 3 seconds and take screenshot", "create folder test and open it"
    # MOVED TO TOP: To prevent other regex patterns from swallowing parts of a chained command.
    if ($UserInput -match '\s+(?:and|then|ve|sonra)\s+') {
        # Split by delimiters, respecting quotes might be needed but for simple commands regex split is okay
        $parts = $UserInput -split '\s+(?:and|then|ve|sonra)\s+'
        
        $chainedCommands = @()
        $descriptions = @()
        $maxRisk = "low"
        
        # Context object to pass data between steps (Basic implementation)
        # We will try to infer if a step produces a path or item that the next step might need.
        # Currently, PowerShell pipeline is the best way, but our intents return strings.
        # We will use a unique variable $LastIntentResult for chaining.
        
        $stepIndex = 0
        foreach ($part in $parts) {
            if ([string]::IsNullOrWhiteSpace($part)) { continue }
            $stepIndex++
            
            # Recursive call to resolve each part
            $jsonRes = Resolve-Intent -UserInput $part
            if ($jsonRes) {
                $subIntent = $jsonRes | ConvertFrom-Json
                if ($subIntent.intent -ne "error") {
                    # === VARIABLE EXPANSION FIX FOR CHAINING ===
                    # If this command creates something (New-Item), capture the path.
                    if ($cmd -match "New-Item\s+.*?(-Path\s+['`"](.+?)['`"])") {
                        $capturedPath = $matches[2]
                        # Inject a variable definition with a unique index based on step count
                        $cmd = "$cmd; `$chainContext_LastPath_$stepIndex = '$capturedPath'"
                    }
                    
                    # If subsequent command uses a generic '$target' or 'it', try to inject the captured path
                    # We look for the most recent path (stepIndex - 1) or specific references if needed
                    # For simple 'it', we use the immediate predecessor.
                    if ($cmd -match '\$target|\$file|\$folder') {
                         $prevIndex = $stepIndex - 1
                         # Replace undefined $target with our captured context variable if available
                         $cmd = $cmd -replace '\$\(.*?target.*?\)', "`$chainContext_LastPath_$prevIndex"
                         $cmd = $cmd -replace '\$target', "`$chainContext_LastPath_$prevIndex"
                    }
                    
                    $chainedCommands += $cmd
                    $descriptions += $subIntent.description
                    
                    # Elevate risk if any step is high risk
                    if ($subIntent.risk -eq "high" -or $subIntent.risk -eq "very_high") { $maxRisk = "high" }
                    elseif ($subIntent.risk -eq "medium" -and $maxRisk -eq "low") { $maxRisk = "medium" }
                }
            }
        }
        
        if ($chainedCommands.Count -gt 1) {
            # FIX: Execute commands in a way that variables are preserved?
            # Actually, standard ';' does preserve variables in the same scope.
            # The issue in "New-Item ...; Start-Process -FilePath $target" is that $target is NOT defined by New-Item.
            # We need to manually inject logic to capture the path.
            
            # Simple Fix for common "Create & Open" pattern:
            # We wrap the New-Item command to pass the object through.
            # "New-Item ... | ForEach-Object { $global:LastItem = $_; $_ }"
            
            # But simpler: Just join with ';'. The user prompt implies "Open IT" relies on AI magic.
            # Since we are in Regex mode, we don't have AI magic here.
            # We must rely on the specific Intent Handlers to return valid standalone commands.
            
            # If the user says "open IT", the 'Resolve-Intent' for the second part likely fails or returns a generic "Start-Process $target".
            # The issue is that the second part "open it" doesn't know the target.
            
            # We will join them simply for now. The specific "Create & Open" bug is that the second command expects a variable that isn't set.
            # To fix this without full context awareness, we can't easily.
            # However, we can ensure the commands are robust.
            
            $fullCommand = $chainedCommands -join "; "
            $fullDesc = $descriptions -join " AND "
            
            $intentObj = @{
                intent = "chained_execution"
                description = "Sequence: $fullDesc"
                target = "multiple"
                action = "chain"
                risk = $maxRisk
                generated_command = $fullCommand
                confirm_level = "none"
            }
            return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
        }
    }
    
    # Pattern: Join Experimental Driver Mode (CLI Command)
    if ($UserInput -match '^\s*/features:intentshell\s+kernel\s+experimental\s+join\s*$') {
        # Feature check removed for rollback
        
        $intentObj = @{
            intent = "experimental_join"
            description = "Join Experimental Driver Mode (Kernel Features)"
            target = "system"
            action = "join_experimental"
            risk = "high" # Trigger high risk warning potentially, but we handle custom flow
            generated_command = "Write-Output 'Initiating Experimental Mode Setup...'" 
            confirm_level = "none" # We handle confirmation in Python UI
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Flow Mode Activation (CLI Feature Flag)
    # "/features:flow mode" or "/features:flow mode -Task 'Coding'"
    if ($UserInput -match '^\s*/features:flow\s+mode(?:\s+(.+))?\s*$') {
        $task = if ($matches[1]) { $matches[1] } else { "Deep Work" }
        # Escape single quotes for PowerShell string
        $safeTask = $task -replace "'", "''"
        $intentObj = @{
            intent = "enter_flow_mode"
            description = "Activate Flow Mode (Task: $task)"
            target = "system_ui"
            action = "enter_flow"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\FlowState.psm1' -Force; Enter-FlowMode -Task '$safeTask'"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Flow Mode Exit
    if ($UserInput -match '^\s*/features:flow\s+exit\s*$') {
        $intentObj = @{
            intent = "exit_flow_mode"
            description = "Exit Flow Mode"
            target = "system_ui"
            action = "exit_flow"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\FlowState.psm1' -Force; Exit-FlowMode"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Wait / Delay
    if ($UserInput -match '(?:wait|sleep|pause|delay)\s+(?:for\s+)?(\d+)\s*(?:seconds|secs|s|minutes|mins|m)(?:\s+(?:and|then|ve|sonra)\s+.*)?$') {
        $val = $matches[1]
        $unit = "Seconds"
        if ($UserInput -match 'minutes|mins|m\b') { $unit = "Minutes" }
        
        $seconds = if ($unit -eq "Minutes") { [int]$val * 60 } else { [int]$val }
        
        # If this is part of a chain (contains 'and', 'then'), let the Chaining Logic handle it
        # NOTE: Since we moved Chaining Logic to the top, this explicit check is technically redundant
        # but kept for safety if regex engine behaves differently with greedy matches.
        if ($UserInput -match '\s+(?:and|then|ve|sonra)\s+') {
             # Fallthrough to chaining logic below (which is now above, so this block should actually return null or handle it)
             # Actually, if we are here, it means the top chaining logic didn't catch it or we are in a sub-recursive call.
             # If we are in a sub-call (e.g. "wait 3 seconds"), the input WON'T have 'and'.
             # If we are here with 'and', it means top logic failed.
             
             # BUT: Since top logic splits by 'and', the recursive calls will NOT have 'and'.
             # So this check is now safe to remove or keep as double-safety.
             # Let's return the intent directly now.
        } 
        
        $intentObj = @{
            intent = "wait_delay"
            description = "Wait for $val $unit"
            target = "system"
            action = "wait"
            risk = "low"
            generated_command = "Start-Sleep -Seconds $seconds"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Intent Chaining (Sequential Commands)
    # "wait 3 seconds and take screenshot", "create folder test and open it"
    # MOVED TO TOP (Code moved to line 62)
    # This block is kept here just for reference or fallback, but the logic is executed at the top.
    
    # 2. Check Legacy Patterns (Regex Heuristics)
    Write-Verbose "Checking Legacy Regex Patterns..."
    
    # Pattern: Copy Shortcut (Turkish & English)
    # TR: "masaüstündeki 'hileko' adlı kısayolu kopyala"
    # EN: "copy shortcut 'cheat' on desktop"
    if ($UserInput -match '(?:masa\u00FCst\u00FCndeki|on desktop)\s+[\u0027\u0022\u2018\u2019](.+?)[\u0027\u0022\u2018\u2019]\s+(?:adl\u0131\s+k\u0131sayolu\s+kopyala|shortcut\s+copy|copy\s+shortcut)') {
        $shortcutName = $matches[1]
        $sourcePath = "$env:USERPROFILE\Desktop\$shortcutName.lnk"
        
        $intentObj = @{
            intent = "copy_file"
            description = "Copy shortcut '$shortcutName' on Desktop"
            target = $sourcePath
            action = "copy"
            risk = "low"
            generated_command = "Copy-Item -Path '$sourcePath' -Destination '$env:USERPROFILE\Desktop\$shortcutName - Copy.lnk' -Force -ErrorAction Stop"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Power Plan
    if ($UserInput -match '(?:power\s+plan|high\s+performance|turn\s+off\s+screen)') {
          $action = "get_power_plan"
          if ($UserInput -match 'high performance') { $action = "set_power_plan" }
          if ($UserInput -match 'turn off') { $action = "turn_off_screen" }
 
          $intentObj = @{
             intent = $action
             description = "Power Management"
             target = "power"
             action = "set"
             risk = "low"
             generated_command = "powercfg /list"
             confirm_level = "none"
         }
         return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
     }

    # Pattern: Shutdown / Restart
    # "shut down the system", "restart computer", "reboot in 5 minutes"
    if ($UserInput -match '(?:shutdown|restart|reboot|power off|turn off)\s+(?:the\s+)?(?:system|computer|pc|machine)?\s*(?:in\s+(\d+)\s*(?:minutes|mins|seconds|secs))?') {
        $action = if ($UserInput -match 'restart|reboot') { "Restart-Computer" } else { "Stop-Computer" }
        $timeVal = if ($matches[1]) { $matches[1] } else { $null }
        
        $cmd = "$action -Force -Confirm:`$false"
        
        # PowerShell Stop-Computer does NOT have -Timeout.
        # We must use Start-Sleep for delay OR use shutdown.exe for native timeout.
        # Using shutdown.exe is more reliable for delayed operations.
        
        if ($timeVal) {
             # Convert to seconds (assuming input is minutes unless specified, but regex assumes minutes context usually)
             # Let's assume minutes for "in X minutes"
             $seconds = [int]$timeVal * 60
             $nativeCmd = if ($action -eq "Restart-Computer") { "shutdown.exe /r /t $seconds" } else { "shutdown.exe /s /t $seconds" }
             $cmd = $nativeCmd
        }
        
        $intentObj = @{
            intent = "system_power"
            description = "$action system $(if($timeVal){"in $timeVal minutes"}else{"immediately"})"
            target = "local_system"
            action = "power_control"
            risk = "high"
            generated_command = $cmd
            confirm_level = "type_yes"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Take Screenshot
    if ($UserInput -match '(?:take|capture|get|save)\s+(?:a\s+)?(?:screen|screenshot|snapshot|ekran\s+g\u00F6r\u00FCnt\u00FCs\u00FC)') {
        $intentObj = @{
            intent = "take_screenshot"
            description = "Capture full screen screenshot"
            target = "screen"
            action = "capture"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\MediaOperations.psm1' -Force; Get-Screenshot"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Get IP Address
    if ($UserInput -match '(?:show|get|what is|tell)\s+(?:me\s+)?(?:my\s+)?(?:current\s+)?(?:ip|ip\s*address|network\s+info|wifi\s+ip)') {
        $intentObj = @{
            intent = "get_ip_address"
            description = "Get current IP address"
            target = "network_adapter"
            action = "get_ip"
            risk = "low"
            generated_command = "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.InterfaceAlias -notmatch 'Loopback' } | Select-Object InterfaceAlias, IPAddress | Format-Table -AutoSize"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: System Hardware Info (CPU, RAM, Disk, GPU, Drivers, Services)
    # CPU
    if ($UserInput -match '(?:show|get|check|how many)\s+(?:cpu|processor|cores)\s*(?:model|info|usage|temp|load|utilization)?') {
        $action = "get_cpu_info"
        if ($UserInput -match 'usage|load') { $action = "get_cpu_usage" }
        if ($UserInput -match 'temp') { $action = "get_cpu_temp" }
        
        $intentObj = @{
            intent = $action
            description = "Get CPU Information ($action)"
            target = "cpu"
            action = "get_info"
            risk = "low"
            generated_command = "Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, MaxClockSpeed | Format-List"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # RAM
    if ($UserInput -match '(?:show|get|check|total|used|free|ram|memory)\s+(?:ram|memory)\s*(?:info|usage|size|speed)?|ram\s+speed') {
        $action = "get_ram_info"
        if ($UserInput -match 'usage|used|free') { $action = "get_ram_usage" }
        if ($UserInput -match 'speed') { $action = "get_ram_speed" }
        
        $intentObj = @{
            intent = $action
            description = "Get RAM Information"
            target = "ram"
            action = "get_info"
            risk = "low"
            generated_command = "Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | Format-List"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Disk
    if ($UserInput -match '(?:list|show|get|check)\s+(?:disks|drives|storage|hdd|ssd)\s*(?:health|usage|info)?|largest\s+folder|disk\s+health|fullest\s+disk') {
        $action = "get_disk_info"
        if ($UserInput -match 'health') { $action = "get_disk_health" }
        if ($UserInput -match 'usage|fullest') { $action = "get_disk_usage" }
        if ($UserInput -match 'largest') { $action = "find_large_items" }
        
        $intentObj = @{
            intent = $action
            description = "Get Disk Information"
            target = "disk"
            action = "get_info"
            risk = "low"
            generated_command = "Get-PSDrive -PSProvider FileSystem"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }
    
    # GPU
    if ($UserInput -match '(?:graphics|gpu|video)\s+(?:card|adapter)?\s*(?:model|info|usage|temp)?') {
         $action = "get_gpu_info"
         if ($UserInput -match 'usage') { $action = "get_gpu_usage" }
         if ($UserInput -match 'temp') { $action = "get_gpu_temp" }

         $intentObj = @{
            intent = $action
            description = "Get GPU Information"
            target = "gpu"
            action = "get_info"
            risk = "low"
            generated_command = "Get-CimInstance Win32_VideoController | Select-Object Name, AdapterRAM, DriverVersion"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Virtualization
    if ($UserInput -match '(?:check|enable|is)\s+(?:virtualization|hyper-v|vm|vt-x)') {
        return (@{
            intent = "check_virtualization_enabled"
            description = "Check Virtualization Status"
            target = "system"
            action = "check_virtualization"
            risk = "low"
            generated_command = "Get-CimInstance Win32_ComputerSystem | Select-Object -ExpandProperty HypervisorPresent"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    # Drivers & Services
    if ($UserInput -match '(?:list|show|get|outdated|battery)\s+(?:drivers|services|printers|wsl distros|status)') {
         $action = "list_services"
         if ($UserInput -match 'drivers') { $action = "list_drivers" }
         if ($UserInput -match 'outdated') { $action = "get_outdated_drivers" }
         if ($UserInput -match 'printers') { $action = "get_printers" }
         if ($UserInput -match 'wsl') { $action = "list_wsl_distros" }
         if ($UserInput -match 'battery') { $action = "get_battery_status" }
         if ($UserInput -match 'stop service') { $action = "stop_service" }
         
         $intentObj = @{
            intent = $action
            description = "List system components ($action)"
            target = "system"
            action = "list"
            risk = "low"
            generated_command = "Get-Service | Select-Object -First 20" # Simplified command
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }
    
    # Stop Service Explicit
    if ($UserInput -match 'stop\s+service\s+(.+)') {
        $svc = $matches[1]
        $intentObj = @{
            intent = "stop_service"
            description = "Stop Service $svc"
            target = $svc
            action = "stop"
            risk = "medium"
            generated_command = "Stop-Service -Name '$svc' -Force"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }


     
     # Symptom / Diagnostics
     if ($UserInput -match '(?:is\s+)?(?:my\s+)?(?:computer|pc|system)\s+(?:is\s+)?(?:slow|lagging|freezing|healthy)|why\s+is\s+it\s+lagging|loud\s+fan|fan\s+noise|heating|overheating|internet|connection|messy|junk|clean\s+junk|deep\s+cleanup') {
          $action = "show_resource_usage"
          if ($UserInput -match 'healthy') { $action = "run_full_diagnostics" }
          if ($UserInput -match 'fan|noise') { $action = "get_fan_speeds" }
          if ($UserInput -match 'heating|overheating') { $action = "get_system_temps" }
          if ($UserInput -match 'internet|connection') { $action = "check_internet" }
          if ($UserInput -match 'messy') { $action = "organize_desktop_smart" }
          if ($UserInput -match 'clean junk') { $action = "clean_all_junk" }
          if ($UserInput -match 'deep cleanup') { $action = "deep_system_cleanup" }
          
          $intentObj = @{
             intent = $action
             description = "Diagnose system state"
             target = "system"
             action = "diagnose"
             risk = "low"
             generated_command = "Get-Process | Sort-Object CPU -Descending | Select-Object -First 10"
             confirm_level = "none"
         }
         return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
     }

    # Pattern: List Files (Enhanced Regex for 'list files in X' or 'list X files')
    if ($UserInput -match '(?:list|show|get|listele|g\u00F6ster)\s+(?:all\s+)?(?:files|items|dosyalar\u0131)?\s*(?:in|i\u00E7indeki|under|from)?\s*(?:the\s+)?(?:klas\u00F6r\u00FC|folder\s+|directory\s+)?[\u0027\u0022\u2018\u2019]?(.+?)[\u0027\u0022\u2018\u2019]?\s*(?:folder|directory|klas\u00F6r\u00FC)?$') {
        $folderName = $matches[1].Trim()
        
        # Filter out generic words or IP requests captured by mistake
        if ($folderName -match '^(?:files|items|dosyalar)$' -or $folderName -match 'ip\s*address') { return $null }

        # Smart Folder Resolution
        $targetPath = "$env:USERPROFILE"
        if ($folderName -match 'Documents|Belgeler') { $targetPath = "$env:USERPROFILE\Documents" }
        elseif ($folderName -match 'Downloads|Indirilenler') { $targetPath = "$env:USERPROFILE\Downloads" }
        elseif ($folderName -match 'Desktop|Masa') { $targetPath = "$env:USERPROFILE\Desktop" }
        elseif ($folderName -match 'Pictures|Resimler') { $targetPath = "$env:USERPROFILE\Pictures" }
        elseif ($folderName -match 'Music|M\u00FCzik') { $targetPath = "$env:USERPROFILE\Music" }
        elseif ($folderName -match 'Videos|Videolar') { $targetPath = "$env:USERPROFILE\Videos" }
        else { $targetPath = Join-Path $env:USERPROFILE $folderName } 

        $intentObj = @{
            intent = "list_files"
            description = "List files in '$folderName'"
            target = $targetPath
            action = "list"
            risk = "low"
            generated_command = "Get-ChildItem -Path '$targetPath'"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Delete Multiple Files (Comma Separated)
    # "delete cd,jd folders in desktop", "masaüstündeki a,b,c dosyalarını sil"
    if ($UserInput -match '(?:sil|delete)\s+(.+?)\s+(?:folders|files|dosyalar\u0131|klas\u00F6rleri)\s+(?:in|on|i\u00E7indeki|under)\s+(?:klas\u00F6r\u00FC|folder\s+|directory\s+|masa\u00FCst\u00FCndeki\s+|desktop\s+)?(.+)$') {
        $targets = $matches[1]
        $location = $matches[2].Trim()
        
        # Smart Folder Resolution
        $basePath = "$env:USERPROFILE"
        if ($location -match 'Documents|Belgeler') { $basePath = "$env:USERPROFILE\Documents" }
        elseif ($location -match 'Downloads|Indirilenler') { $basePath = "$env:USERPROFILE\Downloads" }
        elseif ($location -match 'Desktop|Masa') { $basePath = "$env:USERPROFILE\Desktop" }
        elseif ($location -match 'Pictures|Resimler') { $basePath = "$env:USERPROFILE\Pictures" }
        else { $basePath = Join-Path $env:USERPROFILE $location }

        # Split targets by comma and trim whitespace
        $targetList = $targets -split ',' | ForEach-Object { $_.Trim() }
        
        $deleteCommands = @()
        foreach ($item in $targetList) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $fullPath = Join-Path $basePath $item
                $deleteCommands += "Remove-Item -Path '$fullPath' -Recurse -Force -ErrorAction SilentlyContinue"
            }
        }
        
        if ($deleteCommands.Count -gt 0) {
            $fullCommand = $deleteCommands -join "; "
            
            $intentObj = @{
                intent = "delete_multiple"
                description = "Delete items: '$targets' in '$location'"
                target = "multiple_files"
                action = "delete"
                risk = "high"
                generated_command = $fullCommand
                confirm_level = "type_yes"
            }
            return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
        }
    }

    # Pattern: Delete Folder
    if ($UserInput -match '(?:sil|delete).*(?:klas\u00F6r\u00FC|folder)\s+(?:named\s+|adl\u0131\s+)?[\u0027\u0022\u2018\u2019]?(.+?)[\u0027\u0022\u2018\u2019]?$') {
        $folderName = $matches[1]
        $intentObj = @{
            intent = "delete_folder"
            description = "Delete folder '$folderName'"
            target = $folderName
            action = "delete"
            risk = "high"
            generated_command = "Remove-Item -Path '$folderName' -Recurse -Force -ErrorAction Stop"
            confirm_level = "type_yes"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Delete File (Explicit handling to avoid AI Username hallucination)
    # Matches: "delete the file 'X' in [folder]" or "dosyasını sil"
    # Capture Group 1: File Name
    # Capture Group 2: Folder Name (Optional)
    if ($UserInput -match '(?:sil|delete).*(?:dosyas\u0131n\u0131|file)\s+[\u0027\u0022\u2018\u2019]?(.+?)[\u0027\u0022\u2018\u2019]?\s+(?:in|i\u00E7indeki|under)\s+(?:klas\u00F6r\u00FC|folder\s+|directory\s+)?[\u0027\u0022\u2018\u2019]?(.+?)[\u0027\u0022\u2018\u2019]?$') {
        $fileName = $matches[1]
        $folderName = $matches[2]
        
        # Smart Folder Resolution
        $basePath = "$env:USERPROFILE"
        if ($folderName -match 'Documents|Belgeler') { $basePath = "$env:USERPROFILE\Documents" }
        elseif ($folderName -match 'Downloads|Indirilenler') { $basePath = "$env:USERPROFILE\Downloads" }
        elseif ($folderName -match 'Desktop|Masa') { $basePath = "$env:USERPROFILE\Desktop" }
        elseif ($folderName -match 'Pictures|Resimler') { $basePath = "$env:USERPROFILE\Pictures" }
        else { $basePath = Join-Path $env:USERPROFILE $folderName } # Fallback to user root subdir

        $fullPath = Join-Path $basePath $fileName

        $intentObj = @{
            intent = "delete_file"
            description = "Delete file '$fileName' in '$folderName'"
            target = $fullPath
            action = "delete"
            risk = "high"
            generated_command = "Invoke-SecureDelete -Path '$fullPath' -Passes 1 -Confirm:`$false"
            confirm_level = "type_yes"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Window Operations (Minimize/Restore/Focus)
    # "Chrome penceresini aç", "Notepad'i küçült", "Bütün pencereleri indir"
    
    # Minimize All
    if ($UserInput -match '(?:t\u00FCm|b\u00FCt\u00FCn)\s+pencereleri\s+(?:k\u00FC\u00E7\u00FClt|indir|gizle)|minimize\s+all\s+windows') {
        return (@{
            intent = "minimize_all_windows"
            description = "Minimize all open windows"
            target = "desktop"
            action = "minimize_all"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\WindowOperations.psm1' -Force; Minimize-All-Windows"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    # Focus Window
    if ($UserInput -match '(?:odaklan|ge\u00E7|a\u00E7|focus|switch\s+to)\s+(?:penceresine\s+|window\s+)?[\u0027\u0022\u2018\u2019]?(.+?)[\u0027\u0022\u2018\u2019]?$') {
        $windowName = $matches[1]
        # Exclude if it looks like a generic command (e.g. "experimental join")
        if ($windowName -notmatch "experimental") {
             return (@{
                intent = "focus_window"
                description = "Focus/Switch to window '$windowName'"
                target = $windowName
                action = "focus"
                risk = "low"
                generated_command = "Import-Module '$PSScriptRoot\..\modules\WindowOperations.psm1' -Force; Focus-Window -ProcessName '$windowName'"
                confirm_level = "none"
            } | ConvertTo-Json -Depth 5 -Compress)
        }
    }

    # Focus Window (English Variation: Bring X to front/focus)
    if ($UserInput -match '^(?:bring|move)\s+(?:the\s+)?(.+?)\s+(?:window\s+)?to\s+(?:the\s+)?(?:foreground|front|focus)') {
        $windowName = $matches[1].Trim()
         return (@{
            intent = "focus_window"
            description = "Focus/Switch to window '$windowName'"
            target = $windowName
            action = "focus"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\WindowOperations.psm1' -Force; Focus-Window -ProcessName '$windowName'"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    # Minimize Specific Window
    if ($UserInput -match '(?:k\u00FC\u00E7\u00FClt|minimize)\s+(?:penceresini\s+|window\s+)?[\u0027\u0022\u2018\u2019]?(.+?)[\u0027\u0022\u2018\u2019]?$') {
        $windowName = $matches[1]
        # Exclude if it looks like a generic command (e.g. "experimental join")
        if ($windowName -notmatch "experimental") {
             return (@{
                intent = "minimize_window"
                description = "Minimize window '$windowName'"
                target = $windowName
                action = "minimize"
                risk = "low"
                generated_command = "Import-Module '$PSScriptRoot\..\modules\WindowOperations.psm1' -Force; Minimize-Window -TitlePattern '$windowName'"
                confirm_level = "none"
            } | ConvertTo-Json -Depth 5 -Compress)
        }
    }

    # Pattern: Notes & Reminders
    
    # 1. Add Note/Reminder
    if ($UserInput -match '(?:add|create|new)\s+(?:a\s+)?(?:note|reminder|not|hat\u0131rlat\u0131c\u0131)(?:\s*:\s*|\s+that\s+|\s+about\s+|\s+)(.+)$') {
        $content = $matches[1].Trim()
        $intentObj = @{
            intent = "add_note"
            description = "Add reminder: '$content'"
            target = "notes_db"
            action = "add"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\NoteManager.psm1' -Force; Add-Note -Content '$content'"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # 2. List Notes/Reminders
    if ($UserInput -match '(?:list|show|get|my|read)\s+(?:all\s+)?(?:notes|reminders|notlar|hat\u0131rlat\u0131c\u0131lar)') {
        $intentObj = @{
            intent = "list_notes"
            description = "List all reminders"
            target = "notes_db"
            action = "list"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\NoteManager.psm1' -Force; Get-Notes"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # 3. Delete Note/Reminder
    if ($UserInput -match '(?:delete|remove|sil)\s+(?:note|reminder|not|hat\u0131rlat\u0131c\u0131)(?:\s*:\s*|\s+about\s+|\s+matching\s+|\s+)(.+)$') {
        $target = $matches[1].Trim()
        $intentObj = @{
            intent = "delete_note"
            description = "Delete reminder matching: '$target'"
            target = "notes_db"
            action = "delete"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\NoteManager.psm1' -Force; Remove-Note -Content '$target'"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Media Operations (Volume/Brightness)
    # "Sesi aç", "Sesi kapat", "Parlaklığı 50 yap"
    
    if ($UserInput -match '(?:sesi|volume)\s+(?:a\u00E7|y\u00FCkselt|artt\u0131r|up|increase)') {
        return (@{
            intent = "volume_up"
            description = "Increase System Volume"
            target = "system_audio"
            action = "volume_up"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\MediaOperations.psm1' -Force; Set-Volume -Action Up"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    if ($UserInput -match '(?:sesi|volume)\s+(?:k\u0131s|azalt|indir|d\u00FC\u015F\u00FCr|down|decrease)') {
        return (@{
            intent = "volume_down"
            description = "Decrease System Volume"
            target = "system_audio"
            action = "volume_down"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\MediaOperations.psm1' -Force; Set-Volume -Action Down"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    if ($UserInput -match '(?:sesi|volume)\s+(?:kapat|sustur|mute|sessize\s+al)') {
        return (@{
            intent = "volume_mute"
            description = "Mute/Unmute System Volume"
            target = "system_audio"
            action = "mute"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\MediaOperations.psm1' -Force; Set-Volume -Action Mute"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    if ($UserInput -match '(?:parlakl\u0131\u011F\u0131|brightness)\s+(?:y\u00FCzde\s+)?(\d+)\s*(?:yap|set|seviyesine\s+getir)?') {
        $level = $matches[1]
        return (@{
            intent = "set_brightness"
            description = "Set Screen Brightness to $level%"
            target = "screen"
            action = "set_brightness"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\MediaOperations.psm1' -Force; Set-Brightness -Level $level"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Forensic Analysis (GhostDriver Integration) - Turkish
    # "notepad sürecini analiz et", "chrome uygulamasını tara"
    if ($UserInput -match '(.+?)\s+(?:s\u00FCrecini|uygulamas\u0131n\u0131)\s+(?:analiz et|tara|incele)') {
        $procName = $matches[1].Trim()
        return Get-ForensicIntent -ProcessName $procName
    }

    # Pattern: Forensic Analysis (GhostDriver Integration) - English
    # "analyze notepad process", "inspect chrome", "scan calculator app"
    if ($UserInput -match '^(?:analyze|inspect|scan)\s+(?:process\s+|app\s+|application\s+)?(.+?)$') {
        $procName = $matches[1].Trim()
        return Get-ForensicIntent -ProcessName $procName
    }

    # Pattern: Web Search / Browser
    # "search for cats on google", "open youtube", "go to github.com"
    if ($UserInput -match '(?:search|google|find)\s+(?:for\s+)?(.+?)(?:\s+on\s+(?:google|internet|web))?$') {
        $query = $matches[1]
        $encoded = [System.Web.HttpUtility]::UrlEncode($query)
        # Fallback if HttpUtility not loaded
        if (-not $encoded) { $encoded = $query -replace ' ', '+' }
        
        $intentObj = @{
            intent = "web_search"
            description = "Search web for '$query'"
            target = "browser"
            action = "search"
            risk = "low"
            generated_command = "Start-Process 'https://www.google.com/search?q=$encoded'"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    if ($UserInput -match '(?:go\s+to|open)\s+(?:the\s+)?(?:website\s+|site\s+)?(www\..+|.+\.com|youtube|github|google|facebook|twitter|reddit|linkedin|instagram)') {
        $site = $matches[1]
        if ($site -notmatch '^http') { $site = "https://$site" }
        if ($site -notmatch '\.') { $site = "https://$site.com" } # dumb heuristic for "open youtube" -> youtube.com

        $intentObj = @{
            intent = "open_website"
            description = "Open website '$site'"
            target = "browser"
            action = "open_url"
            risk = "low"
            generated_command = "Start-Process '$site'"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Clean Desktop (Organize Files)
    if ($UserInput -match '(?:clean|tidy)\s+(?:up\s+)?(?:my\s+)?(?:desktop|masa\u00FCst\u00FC)') {
        $script = "
        `$d = [Environment]::GetFolderPath('Desktop');
        `$p = [Environment]::GetFolderPath('MyPictures');
        `$doc = [Environment]::GetFolderPath('MyDocuments');
        Move-Item -Path `"`$d\*.png`", `"`$d\*.jpg`", `"`$d\*.jpeg`", `"`$d\*.gif`" -Destination `$p -Force -ErrorAction SilentlyContinue;
        Move-Item -Path `"`$d\*.pdf`", `"`$d\*.docx`", `"`$d\*.txt`" -Destination `$doc -Force -ErrorAction SilentlyContinue;
        "
        $intentObj = @{
            intent = "clean_desktop"
            description = "Organize Desktop files (Images -> Pictures, Docs -> Documents)"
            target = "desktop"
            action = "organize"
            risk = "medium"
            generated_command = $script -replace "`n", ""
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Close Active Window
    if ($UserInput -match '(?:close|quit|exit)\s+(?:the\s+)?(?:current|active|focused)\s+(?:window|app|application|program)') {
        $intentObj = @{
            intent = "close_active_window"
            description = "Close the currently active window"
            target = "active_window"
            action = "close"
            risk = "medium"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\WindowOperations.psm1' -Force; Close-ActiveWindow"
            confirm_level = "none"
        }
        return ($intentObj | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Ambiguous / Human-Style Helpers
    # "messy screen" -> Minimize All
    if ($UserInput -match '(?:my\s+screen\s+is\s+messy|too\s+many\s+windows|hide\s+everything|clean\s+screen)') {
        return (@{
            intent = "minimize_all_windows"
            description = "Minimize all open windows (Declutter)"
            target = "desktop"
            action = "minimize_all"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\WindowOperations.psm1' -Force; Minimize-All-Windows"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    # "focus mode" -> Enter Flow Mode
    if ($UserInput -match '(?:i\s+want\s+to\s+focus|focus\s+mode|no\s+distractions)') {
        return (@{
            intent = "enter_flow_mode"
            description = "Activate Focus Mode"
            target = "system_ui"
            action = "enter_flow"
            risk = "low"
            generated_command = "Import-Module '$PSScriptRoot\..\modules\FlowState.psm1' -Force; Enter-FlowMode -Task 'Deep Work'"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }
    
    # Pattern: Undo / Cancel (Job based)
    if ($UserInput -match '^(?:undo|cancel|stop|abort)$') {
         return (@{
            intent = "cancel_operation"
            description = "Stop all running background jobs"
            target = "jobs"
            action = "stop"
            risk = "medium"
            generated_command = "Get-Job | Stop-Job -PassThru | Remove-Job; Write-Output 'Stopped all background operations.'"
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    # Pattern: Power User Tests (Macro Placeholders)
    # "Start my daily workflow", "Prepare everything for a meeting"
    
    if ($UserInput -match 'daily\s+workflow|morning\s+routine') {
        # Example Workflow: Open Outlook, Teams, and Chrome
        $cmd = "Start-Process 'outlook'; Start-Process 'ms-teams'; Start-Process 'chrome'; Write-Host 'Daily workflow started.' -ForegroundColor Cyan"
        return (@{
            intent = "macro_daily_workflow"
            description = "Start Daily Workflow (Outlook, Teams, Chrome)"
            target = "workspace"
            action = "run_macro"
            risk = "low"
            generated_command = $cmd
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    if ($UserInput -match 'prepare\s+(?:everything\s+)?for\s+(?:a\s+)?meeting') {
        # Example: Mute volume, open Notepad for notes, minimize distractions
        $cmd = "Import-Module '$PSScriptRoot\..\modules\MediaOperations.psm1' -Force; Set-Volume -Action Mute; Start-Process 'notepad'; Import-Module '$PSScriptRoot\..\modules\WindowOperations.psm1' -Force; Minimize-All-Windows; Write-Host 'Meeting Mode: Volume Muted, Notepad Opened, Distractions Hidden.' -ForegroundColor Cyan"
        return (@{
            intent = "macro_meeting_mode"
            description = "Prepare for Meeting (Mute, Notepad, Clean Screen)"
            target = "workspace"
            action = "run_macro"
            risk = "low"
            generated_command = $cmd
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    if ($UserInput -match 'save\s+(?:this\s+)?session') {
        # Mock Session Save
        $cmd = "Get-Process | Where-Object { `$_.MainWindowTitle } | Select-Object ProcessName, MainWindowTitle | Export-Csv -Path '$env:USERPROFILE\Documents\IntentShell_Session.csv' -NoTypeInformation; Write-Host 'Current session (open apps) saved to Documents.' -ForegroundColor Green"
        return (@{
            intent = "save_session"
            description = "Save current open applications to session file"
            target = "session_manager"
            action = "save"
            risk = "low"
            generated_command = $cmd
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    if ($UserInput -match 'restore\s+(?:my\s+)?(?:last\s+)?workspace|open\s+(?:my\s+)?usual\s+apps') {
        # Mock Session Restore
        $cmd = "Import-Csv '$env:USERPROFILE\Documents\IntentShell_Session.csv' | ForEach-Object { Start-Process `$_.ProcessName -ErrorAction SilentlyContinue }; Write-Host 'Restoring previous session apps...' -ForegroundColor Green"
        return (@{
            intent = "restore_session"
            description = "Restore apps from saved session"
            target = "session_manager"
            action = "restore"
            risk = "medium"
            generated_command = $cmd
            confirm_level = "none"
        } | ConvertTo-Json -Depth 5 -Compress)
    }

    # 3. Fallback to AI Engine
    Write-Verbose "Registry Miss. Calling AI Engine..."
    
    # Policy Feature check removed for rollback
    $useAdvancedAI = $true
    
    # Use Global Config if available, otherwise defaults
    $aiParams = @{ UserInput = $UserInput }
    
    if ($Global:IntentShellConfig) {
        $aiParams.Provider = $Global:IntentShellConfig.Provider
        $aiParams.Model = if ($useAdvancedAI) { $Global:IntentShellConfig.Model } else { "llama-3.3-70b-versatile" } # Fallback or restricted model
        $aiParams.Url = $Global:IntentShellConfig.Url
        $aiParams.ApiKey = $Global:IntentShellConfig.ApiKey
    }
    
    # If policy completely forbids AI fallback (e.g. strict offline mode)
    # if (-not $useAdvancedAI) { return ... error ... } 
    
    $aiIntent = Invoke-IntentGeneration @aiParams
    
    if ($aiIntent) {
        return ($aiIntent | ConvertTo-Json -Depth 5 -Compress)
    }
    
    # 4. Error
    return (@{
        intent = "error"
        description = "Could not resolve intent"
        risk = "low"
    } | ConvertTo-Json -Compress)
}

Export-ModuleMember -Function Resolve-Intent
