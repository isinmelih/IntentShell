import os
import tempfile
import shutil
from typing import Optional, Tuple
from .schemas import Intent, RiskLevel

class SandboxManager:
    """
    Manages a safe, isolated environment for testing commands.
    It creates a temporary directory structure and modifies file-system related commands
    to operate within this sandbox.
    """
    def __init__(self):
        self.sandbox_root = os.path.join(tempfile.gettempdir(), "IntentShell_Sandbox")
        self.is_active = False

    def setup(self):
        """Creates the sandbox environment."""
        if os.path.exists(self.sandbox_root):
            shutil.rmtree(self.sandbox_root)
        os.makedirs(self.sandbox_root)
        # Create some dummy folders to mimic a real environment
        os.makedirs(os.path.join(self.sandbox_root, "Desktop", "Images"))
        os.makedirs(os.path.join(self.sandbox_root, "Desktop", "Documents"))
        os.makedirs(os.path.join(self.sandbox_root, "Downloads"))
        with open(os.path.join(self.sandbox_root, "Desktop", "test_file.txt"), "w") as f:
            f.write("This is a sandbox test file.")
        self.is_active = True
        return self.sandbox_root

    def teardown(self):
        """Cleans up the sandbox environment."""
        if os.path.exists(self.sandbox_root):
            try:
                shutil.rmtree(self.sandbox_root)
            except Exception as e:
                print(f"Error cleaning up sandbox: {e}")
        self.is_active = False

    def transform_command(self, command: str, intent: Intent) -> Tuple[str, str]:
        """
        Transforms a PowerShell command to run in the sandbox.
        Returns (new_command, description_of_change).
        """
        if not self.is_active:
            self.setup()

        # Path Redirection Logic
        # We replace common paths with sandbox paths
        sandbox_desktop = os.path.join(self.sandbox_root, "Desktop")
        sandbox_downloads = os.path.join(self.sandbox_root, "Downloads")
        
        new_cmd = command
        modifications = []

        # 1. Replace $HOME variables if used in PowerShell
        if "$HOME" in new_cmd:
            # We can't easily replace $HOME env var in PS session without more complex logic,
            # but we can replace string occurrences if the command uses them directly.
            # A better approach for specific known paths:
            pass

        # 2. Redirect specific target paths from Intent
        # If the intent targets Desktop or Downloads, we rewrite the command logic
        # This is tricky with raw PowerShell strings. 
        # Strategy: Prepend path variables to the command.
        
        # Simple string replacement for demonstration of concept
        # In a real robust system, we'd parse the AST, but here we do string replacement
        
        mappings = {
            "$HOME\\Desktop": sandbox_desktop,
            "$HOME/Desktop": sandbox_desktop,
            os.path.join(os.environ['USERPROFILE'], 'Desktop'): sandbox_desktop,
            # "Desktop": sandbox_desktop, # REMOVED: Causes recursive replacement issue
            
            "$HOME\\Downloads": sandbox_downloads,
            "$HOME/Downloads": sandbox_downloads,
            os.path.join(os.environ['USERPROFILE'], 'Downloads'): sandbox_downloads,
            # "Downloads": sandbox_downloads # REMOVED: Causes recursive replacement issue
        }
        
        for original, replacement in mappings.items():
            if original in new_cmd:
                new_cmd = new_cmd.replace(original, replacement)
                modifications.append(f"Redirected '{original}' -> Sandbox")

        # 3. Handle System Commands (High Risk)
        if intent.risk == RiskLevel.HIGH:
            if "shutdown" in new_cmd or "Restart-Computer" in new_cmd or "Stop-Service" in new_cmd:
                return (f'Write-Host "[SANDBOX BLOCKED] Destructive command intercepted: {command}" -ForegroundColor Yellow', "Blocked High Risk Command")

        # 4. Wrap in a try-catch block for reporting
        wrapped_cmd = f"""
        Write-Host "[SANDBOX MODE] Executing in: {self.sandbox_root}" -ForegroundColor Cyan
        try {{
            {new_cmd}
            Write-Host "[SANDBOX SUCCESS] Command completed without errors." -ForegroundColor Green
        }} catch {{
            Write-Host "[SANDBOX ERROR] $_" -ForegroundColor Red
        }}
        """
        
        return wrapped_cmd, ", ".join(modifications) if modifications else "Executed in Sandbox"

