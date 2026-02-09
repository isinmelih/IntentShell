import os
import json
import subprocess
import sys
import hashlib
from typing import Optional
from .schemas import Intent, RiskLevel
from .powershell_session import PowerShellSession

class NLUBridge:
    def __init__(self, session: Optional[PowerShellSession] = None):
        self.session = session
        self.cache_file = "cache/intent_cache.json"
        self.cache = self._load_cache()

    def _load_cache(self) -> dict:
        if not os.path.exists("cache"):
            os.makedirs("cache")
        if os.path.exists(self.cache_file):
            try:
                with open(self.cache_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except:
                return {}
        return {}

    def _save_cache(self):
        try:
            with open(self.cache_file, "w", encoding="utf-8") as f:
                json.dump(self.cache, f, indent=2)
        except Exception as e:
            print(f"Cache Save Error: {e}")

    def cache_successful_execution(self, user_input: str, intent_data: dict):
        """
        Explicitly caches the intent ONLY after successful execution confirmation.
        This prevents caching hallucinations or incorrect commands.
        """
        if not user_input or not intent_data:
            return

        # Check Learning Freeze Mode
        if self._is_learning_freeze_enabled():
            print("❄️ Learning Freeze Mode Active: Skipping cache update.")
            return

        input_hash = hashlib.md5(user_input.strip().lower().encode()).hexdigest()
        
        # Don't cache errors
        if intent_data.get("intent") in ["error", "unknown", "kernel_error"]:
            return

        # Don't cache dynamic queries (like 'close tab')
        if "close" in user_input.lower() and "tab" in user_input.lower():
            return

        self.cache[input_hash] = intent_data
        self._save_cache()
        print(f"✅ Intent cached for: '{user_input}'")

    def _is_learning_freeze_enabled(self) -> bool:
        try:
            config_path = os.path.join("config", "main.ini")
            import configparser
            config = configparser.ConfigParser()
            if os.path.exists(config_path):
                config.read(config_path, encoding='utf-8')
                if config.has_option("LearningFreeze", "enabled"):
                    return config.getboolean("LearningFreeze", "enabled")
            return False
        except:
            return False

    def resolve_intent(self, user_input: str, bypass_cache: bool = False) -> Intent:
        """
        Bridges the user input to the PowerShell Kernel for intent resolution.
        """
        safe_input = user_input.replace("'", "''")
        
        # 1. Check Cache
        # Force refresh for 'close chrome tab' related queries to fix stuck cache issue
        is_chrome_tab_query = "close" in user_input.lower() and "tab" in user_input.lower()
        input_hash = hashlib.md5(user_input.strip().lower().encode()).hexdigest()
        
        if not bypass_cache and not is_chrome_tab_query and input_hash in self.cache:
            print("⚡ Cache Hit! Returning cached intent.")
            return self._dict_to_intent(self.cache[input_hash])

        # Script block for Persistent Session
        # Modules are already loaded in session init
        ps_script = f"""
        $json = Resolve-Intent -UserInput '{safe_input}'
        Write-Output $json
        """
        
        try:
            if self.session:
                # Fast Path: Persistent Session
                json_str = self.session.run_command(ps_script)
                if not json_str.strip():
                     # Fallback or error handling
                     pass
            else:
                # Slow Path: Spawning new process (Legacy/Fallback)
                # Note the updated paths: engine/kernel and engine/intelligence
                full_script = f"""
                [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                Import-Module "{os.getcwd()}\\engine\\intelligence\\AIEngine.psm1" -Force
                Import-Module "{os.getcwd()}\\engine\\kernel\\Registry.psm1" -Force
                Import-Module "{os.getcwd()}\\engine\\kernel\\IntentResolver.psm1" -Force
                
                {ps_script}
                """
                result = subprocess.run(
                    ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", full_script],
                    capture_output=True, text=True, encoding='utf-8',
                    creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
                )
                json_str = result.stdout.strip()

            if json_str:
                # Remove potential ERROR prefix if caught in session wrapper
                if json_str.startswith("ERROR:"):
                     print(f"Kernel Error: {json_str}")
                     return self._error_intent(json_str)

                try:
                    data = json.loads(json_str)
                    
                    # DO NOT CACHE HERE ANYMORE
                    # We only return the object. Caching is now handled by the UI layer after execution.
                    
                    return self._dict_to_intent(data)

                except json.JSONDecodeError:
                    print(f"JSON Parse Error from Kernel: {json_str}")
            else:
                print(f"Kernel returned empty result")
                
        except Exception as e:
            print(f"Bridge Call Error: {e}")
            
        return self._error_intent("Failed to resolve intent via PowerShell Kernel.")

    def _dict_to_intent(self, data: dict) -> Intent:
        # Risk mapping
        risk_str = data.get("risk", "low").lower()
        if risk_str == "very_high": risk = RiskLevel.VERY_HIGH
        elif risk_str == "high": risk = RiskLevel.HIGH
        elif risk_str == "medium": risk = RiskLevel.MEDIUM
        else: risk = RiskLevel.LOW
        
        return Intent(
            intent_type=data.get("intent", "unknown"),
            target=data.get("target", "system"),
            action=data.get("action", "run"),
            filters=data.get("filters", []),
            recursive=data.get("recursive", False),
            risk=risk,
            description=data.get("description", "PowerShell Engine Action"),
            generated_command=data.get("generated_command", None),
            requires_elevation=data.get("requires_elevation", False),
            confirm_level=data.get("confirm_level", "none"),
            protocol_version=data.get("protocol_version", "intent-v1")
        )

    def _error_intent(self, msg: str) -> Intent:
        return Intent(
            intent_type="kernel_error",
            target="system",
            risk=RiskLevel.LOW,
            description=msg
        )
