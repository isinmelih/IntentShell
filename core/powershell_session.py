import subprocess
import json
import os
import sys
import uuid
import time
import base64
import threading
import queue
import shutil
from typing import Optional

import datetime
from ui.security_dialogs import show_ghost_mode_warning

class PowerShellSession:
    """
    Manages a persistent PowerShell process for low-latency command execution.
    """
    def __init__(self):
        self.process = None
        self.delimiter = f"END_OF_RESPONSE_{uuid.uuid4().hex}"
        # Runtime state only. Not persisted to disk. Resets on session restart.
        self.ghost_mode_active = False 
        self.experimental_mode_active = False
        self.read_timeout_seconds = int(os.getenv("INTENTSHELL_READ_TIMEOUT", "20"))
        
        # Threading for non-blocking I/O
        self.output_queue = queue.Queue()
        self.reader_thread = None
        self.stop_reader = False
        
        self._start_session()

    def enable_experimental_mode(self):
        """
        Enables Experimental Driver Mode for the current session.
        """
        from core.security.kernel_guard import assert_kernel_disabled
        assert_kernel_disabled()

    def enable_ghost_mode(self, parent_window=None) -> bool:
        """
        Triggers the 'Legal Shield' UI and enables Ghost Mode if authorized.
        """
        from core.security.kernel_guard import assert_kernel_disabled
        assert_kernel_disabled()

    def _reader_loop(self):
        """Reads stdout in a separate thread and puts lines into a queue."""
        while not self.stop_reader and self.process:
            try:
                line = self.process.stdout.readline()
                if not line:
                    break
                self.output_queue.put(line)
            except Exception:
                break

    def _start_session(self):
        """Starts the persistent PowerShell process."""
        try:
            # Use PowerShell Core (pwsh) 7+
            pwsh_path = shutil.which("pwsh")
            if not pwsh_path:
                 # Fallback for standard installation
                 pwsh_path = r"C:\Program Files\PowerShell\7\pwsh.exe"
                 if not os.path.exists(pwsh_path):
                     print("Error: PowerShell 7 (pwsh) not found.")
                     self.process = None
                     return

            cmd = [pwsh_path, "-NoProfile", "-NoLogo", "-ExecutionPolicy", "Bypass", "-Command", "-"]
            
            # Windows specific flag to hide window
            creation_flags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            
            self.process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, # Merge stderr into stdout to prevent blocking buffers
                text=True,
                encoding='utf-8',
                bufsize=1, # Line buffered
                creationflags=creation_flags
            )
            
            # Start reader thread
            self.stop_reader = False
            # Clear old queue if any
            while not self.output_queue.empty():
                try:
                    self.output_queue.get_nowait()
                except queue.Empty:
                    break
            
            self.reader_thread = threading.Thread(target=self._reader_loop, daemon=True)
            self.reader_thread.start()
            
            # Initial setup: Load Modules and Config
            from config.settings import settings
            
            init_script = f"""
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $ErrorActionPreference = 'Stop'
            
            # Global Config
            $Global:IntentShellConfig = @{{
                Provider = "Groq"
                ApiKey = "{settings.GROQ_API_KEY}"
                Model = "{settings.MODEL_NAME}"
                Url = "https://api.groq.com/openai/v1/chat/completions"
                ExperimentalModeEnabled = $false # Kernel mode cannot be enabled via config, env, or runtime flags.
                Security = @{{
                    EnableGhostMode = $false # Always start False. Cannot be enabled.
                }}
            }}
            
            # Load System Core (Phase 22) - MUST BE LOADED FIRST
            # Defines SystemModule interface and SystemCore orchestrator
            Import-Module "{os.getcwd()}\\engine\\modules\\SystemCore.psm1" -Force

            # Load Creative Core (Phase 20)
            # Defines CreativeModule interface
            Import-Module "{os.getcwd()}\\engine\\modules\\CreativeCore.psm1" -Force
            
            # Load Kernel Modules
            Import-Module "{os.getcwd()}\\engine\\intelligence\\AIEngine.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\kernel\\Registry.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\kernel\\IntentResolver.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\kernel\\CommandGenerator.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\kernel\\Sentinel.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\kernel\\ExecutionEngine.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\WindowOperations.psm1" -Force 
            Import-Module "{os.getcwd()}\\engine\\modules\\MediaOperations.psm1" -Force 
            Import-Module "{os.getcwd()}\\engine\\modules\\FileOperations.psm1" -Force 
            
            # Load Path Resolution (Phase 21) - Implements SystemModule
            Import-Module "{os.getcwd()}\\engine\\modules\\PathResolution.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\SafetyCheck.psm1" -Force
            
            # Load Intelligence Modules (Phase 16)
            Import-Module "{os.getcwd()}\\engine\\modules\\ProcessIntelligence.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\SecurityInspection.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\RegistryIntelligence.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\NetworkAwareness.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\SystemForensics.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\IntentLearning.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\ExperimentalLab.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\Diagnostics.psm1" -Force

            # Load Advanced Cognitive Modules (Phase 17)
            Import-Module "{os.getcwd()}\\engine\\modules\\ContextAwareness.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\IntentChaining.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\ExplainableActions.psm1" -Force

            # Load Daily Utility Modules (Phase 18)
            Import-Module "{os.getcwd()}\\engine\\modules\\IntentHistory.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\AutoFix.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\EnvManager.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\SmartSearch.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\MacroManager.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\OutputFormatter.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\OfflineCapabilities.psm1" -Force

            # Load Performance Profiler (Phase 19)
            Import-Module "{os.getcwd()}\\engine\\modules\\PerformanceProfiler.psm1" -Force

            # Load Creativity & Flow Modules (Phase 20)
            Import-Module "{os.getcwd()}\\engine\\modules\\IdeaScratchpad.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\FlowState.psm1" -Force
            Import-Module "{os.getcwd()}\\engine\\modules\\CreativeStudio.psm1" -Force

            Write-Output "SESSION_READY"
            """
            
            response = self.run_command(init_script, is_init=True)
            if "SESSION_READY" not in response:
                print(f"Warning: Session Init failed. Output: {response}")
                
        except Exception as e:
            print(f"Failed to start persistent PowerShell session: {e}")
            self.process = None

    def run_command(self, script_block: str, is_init: bool = False) -> str:
        """
        Runs a script block in the persistent session and returns stdout.
        """
        if not self.process or self.process.poll() is not None:
            print("Session dead, restarting...")
            self._start_session()
            if not is_init:
                # Re-run init if we just restarted and this wasn't the init call
                pass 

        if not self.process:
            return ""

        try:
            # Wrap command to ensure we get a delimiter
            # We use base64 for complex objects usually, but here we expect text output
            # We add a trap for errors to print them to stdout so we can capture them
            wrapped_command = f"""
            try {{
                {script_block}
            }} catch {{
                Write-Output "ERROR: $_"
            }}
            Write-Output "{self.delimiter}"
            """
            
            # Encode command to Base64 to avoid newline/comment issues
            encoded = base64.b64encode(wrapped_command.encode('utf-16le')).decode('utf-8')
            command_to_send = f"$c = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('{encoded}')); Invoke-Expression $c"

            # Write to stdin
            try:
                self.process.stdin.write(command_to_send + "\n")
                self.process.stdin.flush()
            except Exception:
                 # If write fails, session might be dead
                 return "ERROR: Write failed"
            
            # Read from stdout until delimiter (using queue for timeout support)
            output = []
            start_time = time.time()
            
            while True:
                try:
                    # Calculate remaining time
                    elapsed = time.time() - start_time
                    remaining = self.read_timeout_seconds - elapsed
                    
                    if not is_init and remaining <= 0:
                        output.append("ERROR: TIMEOUT waiting for response")
                        # We might want to kill the process here since it's stuck?
                        # For now just return error
                        break

                    # Wait for line from queue
                    # If is_init is True, we can wait longer or forever? 
                    # Let's use a longer timeout for init or just large number
                    timeout_val = remaining if not is_init else 60.0 
                    
                    line = self.output_queue.get(timeout=timeout_val)
                    
                    # Check raw line first before stripping
                    clean_line = line.strip()
                    if clean_line == self.delimiter:
                        break
                    
                    # Filter out empty lines if they are just noise? No, preserve intent.
                    output.append(clean_line)
                    
                except queue.Empty:
                    if not is_init:
                        output.append("ERROR: TIMEOUT waiting for response")
                        break
                    # If init, keep waiting? Or fail?
                    # Init usually takes time.
                
            return "\n".join(output)
            
        except Exception as e:
            print(f"Session Communication Error: {e}")
            return ""

    def close(self):
        self.stop_reader = True
        if self.process:
            self.process.terminate()
