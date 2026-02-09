import subprocess
import os
import sys
import base64
from typing import Callable, Optional
from core.schemas import Intent
from core.powershell_session import PowerShellSession

class RunnerBridge:
    """
    Thin Bridge to the Kernel Execution Engine.
    Does NOT execute commands directly via subprocess.run(command).
    Delegates execution to Invoke-SafePowerShell in the Kernel.
    """
    
    def __init__(self, output_callback: Optional[Callable[[str, str], None]] = None, session: Optional[PowerShellSession] = None):
        """
        :param output_callback: Function to handle output (text, style/type). 
                                style can be 'info', 'error', 'success', 'warning'.
        :param session: Persistent PowerShellSession instance.
        """
        self.output_callback = output_callback
        self.session = session

    def _log(self, text: str, style: str = "info"):
        if self.output_callback:
            self.output_callback(text, style)
        else:
            # Fallback to print if no callback
            print(f"[{style.upper()}] {text}")

    def dry_run(self, command: str, description: str) -> None:
        """
        Simulates execution.
        """
        self._log("\n--- DRY RUN SIMULATION ---", "warning")
        self._log(f"Would execute: {command}", "info")
        self._log(f"Description: {description}", "info")
        self._log("(No changes were made to the system)\n", "dim")

    def execute(self, command: str, intent: Optional[Intent] = None, timeout: int = 60) -> bool:
        """
        Delegates execution to the Kernel via Invoke-SafePowerShell.
        """
        self._log(f"EXECUTING (Kernel): {command}", "info")
        
        # Prepare params
        risk = "low"
        desc = "Unknown"
        if intent:
            risk = intent.risk.value if hasattr(intent.risk, 'value') else str(intent.risk)
            desc = intent.description
            
        # Construct Kernel Call
        # We pass -Confirmed because this method is only called after UI confirmation
        
        # Base64 encode command to avoid escaping issues
        b64_cmd = base64.b64encode(command.encode('utf-16le')).decode('utf-8')
        
        ps_script = f"""
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        Import-Module "{os.getcwd()}\\engine\\kernel\\ExecutionEngine.psm1" -Force
        Import-Module "{os.getcwd()}\\engine\\kernel\\Sentinel.psm1" -Force
        
        $cmdBytes = [System.Convert]::FromBase64String('{b64_cmd}')
        $cmd = [System.Text.Encoding]::Unicode.GetString($cmdBytes)
        
        Invoke-SafePowerShell -Command $cmd -Description '{desc.replace("'", "''")}' -Risk '{risk}' -Confirmed -ProtocolVersion 'intent-v1'
        """
        
        try:
            if self.session:
                # Use persistent session
                output = self.session.run_command(ps_script)
                # Check output for errors or success
                # The Kernel Invoke-SafePowerShell should write output to stdout
                
                if output:
                    # Simple heuristic for now: check if it looks like an error
                    if "SECURITY BLOCK" in output or "Execution Failed" in output or "Error:" in output:
                        self._log(output.strip(), "error")
                        return False
                    else:
                        self._log(output.strip(), "info")
                        self._log("SUCCESS", "success")
                        return True
                else:
                    # Empty output usually means success for void commands, or silence
                    self._log("SUCCESS (No Output)", "success")
                    return True

            else:
                # Fallback to subprocess
                result = subprocess.run(
                    ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script],
                    capture_output=True,
                    text=True,
                    encoding='utf-8',
                    timeout=timeout,
                    creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
                )
                
                if result.stdout:
                    self._log(result.stdout.strip(), "info")
                
                if result.stderr:
                    self._log(f"KERNEL ERROR: {result.stderr.strip()}", "error")
                    return False
                    
                if result.returncode == 0:
                    self._log("SUCCESS", "success")
                    return True
                else:
                    self._log(f"FAILED with code {result.returncode}", "error")
                    return False
                
        except subprocess.TimeoutExpired:
            self._log(f"TIMEOUT ({timeout}s) - Command killed", "error")
            return False
        except Exception as e:
            self._log(f"EXCEPTION: {e}", "error")
            return False
