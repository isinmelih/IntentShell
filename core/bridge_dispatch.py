import subprocess
import json
import os
import sys
import base64
from typing import Optional
from .schemas import Intent
from .powershell_session import PowerShellSession

class DispatchBridge:
    """
    Bridges the command generation request to the PowerShell Kernel.
    """
    def __init__(self, session: Optional[PowerShellSession] = None):
        self.session = session

    def get_safe_command(self, intent: Intent) -> str:
        """
        Invokes the PowerShell Kernel (CommandGenerator.psm1) to convert the Intent into a Safe Command.
        """
        # If the intent already has a generated command (e.g. from LLM or Registry), return it.
        # The Kernel (Resolve-Intent) is responsible for populating this.
        if intent.generated_command:
             return intent.generated_command

        # If no generated command, ask the Kernel to build one (fallback for legacy/simple intents).
        
        # Base64 encode intent JSON to avoid string escaping issues in PowerShell
        json_str = intent.model_dump_json()
        b64_json = base64.b64encode(json_str.encode('utf-8')).decode('utf-8')

        ps_script = f"""
        # Pass intent as JSON
        $jsonBytes = [System.Convert]::FromBase64String('{b64_json}')
        $jsonStr = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
        $intentObj = $jsonStr | ConvertFrom-Json
        
        ConvertTo-SafePowerShellCommand -Intent $intentObj
        """
        
        try:
            if self.session:
                cmd = self.session.run_command(ps_script)
                if cmd and not cmd.startswith("ERROR:"):
                    return cmd.strip()
            else:
                full_script = f"""
                [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                Import-Module "{os.getcwd()}\\engine\\kernel\\CommandGenerator.psm1" -Force
                {ps_script}
                """
                result = subprocess.run(
                    ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", full_script],
                    capture_output=True, text=True, encoding='utf-8',
                    creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
                )
                if result.returncode == 0:
                    cmd = result.stdout.strip()
                    if cmd:
                        return cmd
                else:
                    print(f"Kernel Generation Error: {result.stderr}")
                
        except Exception as e:
            print(f"Dispatch Bridge Error: {e}")
            
        return f"# Error: Could not generate command for {intent.action} {intent.target}"
