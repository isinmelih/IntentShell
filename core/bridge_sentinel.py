import subprocess
import json
import os
import sys
import base64
from typing import Optional
from core.schemas import Intent, RiskAssessment, RiskLevel
from .powershell_session import PowerShellSession
from .security.anti_pattern import AntiPatternDetector
from .security.risk_classifier import RiskClassifier

import time

class SuspensionSystem:
    def __init__(self, threshold: float = 5.0):
        self.threshold = threshold
        self.cumulative_risk_score = 0.0
        self.suspended = False
        self.last_intent_type = None
        self.suspension_reasons = []
        self.suspension_start_time = 0
        self.SUSPENSION_DURATION = 600 # 10 minutes

    def _is_safe_context(self, command: str) -> bool:
        """
        Checks if the command is operating within the current working directory (CWD)
        and NOT touching sensitive system paths.
        """
        try:
            cwd = os.getcwd().lower()
            cmd_lower = command.lower()
            
            # Simple heuristic: command uses relative paths or explicitly references CWD
            is_local = "./" in cmd_lower or ".\\" in cmd_lower or cwd in cmd_lower or not (":" in cmd_lower or "\\" in cmd_lower)
            
            # Blacklist check (Safety net)
            # Even if local, we don't want to mess with Windows folder if somehow CWD is C:\Windows
            is_system_path = "windows" in cwd or "system32" in cwd or "program files" in cwd
            
            return is_local and not is_system_path
        except:
            return False

    def record_risk(self, risk_level: RiskLevel, command: str, intent_type: str, anti_patterns: list):
        # 1. Action-based Decay (Risk Eraser)
        if risk_level not in [RiskLevel.HIGH, RiskLevel.VERY_HIGH]:
            # Decay risk on safe commands
            # If user does something safe, we forgive 15% of the accumulated risk + flat 0.5
            self.cumulative_risk_score = max(0, (self.cumulative_risk_score * 0.85) - 0.5)
            return

        # Calculate Weight
        classification, weight = RiskClassifier.classify_destructive(command)
        
        # Context Dampener (Sandbox Effect)
        if self._is_safe_context(command) and "Critical" in classification:
            weight = 1.0 # Reduce Critical (2.0) to Standard (1.0) if in safe context
            classification += " (Safe Context)"

        # Anti-Pattern Penalties
        if anti_patterns:
            weight += 2.0 # Base penalty for suspicion
            if any("Obfuscation" in p for p in anti_patterns):
                weight += 1.0
            if any("Chaining" in p for p in anti_patterns):
                weight += 1.0

        # Intent Inertia & Smart Merge
        # If same intent type AND same risk weight (likely same scope)
        if self.last_intent_type == intent_type and weight < 2.0:
             # Repeating the same routine destructive action
             # We treat this as a "single event" effectively by severely damping subsequent calls
             weight *= 0.2 # Drastic reduction for routine repetition
        
        self.cumulative_risk_score += weight
        self.last_intent_type = intent_type
        
        # Log reason for potential suspension
        self.suspension_reasons.append(f"{classification} (Weight: {weight:.2f})")

        if self.cumulative_risk_score >= self.threshold:
            self.suspended = True
            self.suspension_start_time = time.time()

    def is_suspended(self) -> bool:
        if self.suspended:
            # Check Temporary Suspension Expiry
            elapsed = time.time() - self.suspension_start_time
            if elapsed > self.SUSPENSION_DURATION:
                self.reset() # Auto-forgive after duration
                return False
        return self.suspended
        
    def get_warning(self) -> Optional[str]:
        # Forgiveness Window Warning
        if not self.suspended and self.cumulative_risk_score >= (self.threshold - 2.0) and self.cumulative_risk_score > 0:
            return f"⚠️ Forgiveness Window Active: High Risk (Score: {self.cumulative_risk_score:.1f}/{self.threshold}). Run safe commands to lower risk."
        return None

    def get_suspension_details(self) -> list:
        remaining = int(self.SUSPENSION_DURATION - (time.time() - self.suspension_start_time))
        if remaining < 0: remaining = 0
        mins, secs = divmod(remaining, 60)
        
        details = list(self.suspension_reasons)
        details.append(f"Suspension lifts in: {mins}m {secs}s")
        details.append("Alternatively: Restart IntentShell to reset immediately.")
        return details

    def reset(self):
        self.cumulative_risk_score = 0.0
        self.suspended = False
        self.last_intent_type = None
        self.suspension_reasons = []
        self.suspension_start_time = 0

class SentinelBridge:
    """
    Bridge to the PowerShell Sentinel (Security Engine).
    Delegates all risk assessment to the Kernel.
    """
    def __init__(self, session: Optional[PowerShellSession] = None):
        self.session = session
        self.suspension_system = SuspensionSystem()

    def assess(self, intent: Intent, command: str) -> RiskAssessment:
        """
        Calls the Kernel's Measure-Risk function.
        """
        # 1. Check Suspension
        if self.suspension_system.is_suspended():
             reasons = ["⛔ Session Suspended"]
             reasons.append("🔍 Reasoning:")
             for r in self.suspension_system.get_suspension_details():
                 reasons.append(f" - {r}")
             reasons.append("Combined risk exceeded safety threshold.")
             
             return RiskAssessment(
                level=RiskLevel.VERY_HIGH,
                reasons=reasons,
                score=100
            )

        # If no command generated yet, assessment is partial but we still check Intent target
        cmd_arg = command if command else ""
        
        # 2. Check Anti-Patterns (Pre-Kernel Check)
        suspicious_patterns = AntiPatternDetector.scan(cmd_arg)
        if suspicious_patterns:
            # If patterns found, we escalate risk IMMEDIATELY
            # We still let the Kernel run for full analysis, but we force HIGH risk
            pass # We will merge this into the assessment later
        
        # Base64 encode intent JSON to avoid string escaping issues in PowerShell
        json_str = intent.model_dump_json()
        b64_json = base64.b64encode(json_str.encode('utf-8')).decode('utf-8')
        
        ps_script = f"""
        $jsonBytes = [System.Convert]::FromBase64String('{b64_json}')
        $jsonStr = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
        $intentObj = $jsonStr | ConvertFrom-Json
        
        $cmd = '{cmd_arg.replace("'", "''")}'
        
        $result = Measure-Risk -Intent $intentObj -Command $cmd
        $result | ConvertTo-Json -Depth 5 -Compress
        """
        
        try:
            assessment = None
            if self.session:
                output = self.session.run_command(ps_script)
                if output and not output.startswith("ERROR:"):
                     assessment = self._parse_output(output)
            else:
                full_script = f"""
                [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                Import-Module "{os.getcwd()}\\engine\\kernel\\Sentinel.psm1" -Force
                {ps_script}
                """
                result = subprocess.run(
                    ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", full_script],
                    capture_output=True, text=True, encoding='utf-8',
                    creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
                )
                if result.returncode == 0:
                     assessment = self._parse_output(result.stdout.strip())
                else:
                    print(f"Sentinel Kernel Error: {result.stderr}")
            
            if assessment:
                # Merge Anti-Pattern Detections
                if suspicious_patterns:
                    assessment.level = RiskLevel.HIGH # Force upgrade
                    assessment.reasons.extend(suspicious_patterns)
                    assessment.score += 50 # Penalty

                # Record risk for suspension logic
                self.suspension_system.record_risk(assessment.level, cmd_arg, intent.intent_type, suspicious_patterns)
                
                # Append Warning if exists
                warning = self.suspension_system.get_warning()
                if warning:
                    assessment.reasons.append(warning)
                    
                return assessment
                
        except Exception as e:
            print(f"Sentinel Bridge Error: {e}")
            
        # Fallback (Safe Mode)
        return RiskAssessment(
            level=RiskLevel.HIGH,
            reasons=["Sentinel Bridge Failed - Failing Open to High Risk"],
            score=100
        )

    def _parse_output(self, output: str) -> RiskAssessment:
        if output:
            try:
                data = json.loads(output)
                return RiskAssessment(
                    level=RiskLevel(data.get("level", "low")),
                    reasons=data.get("reasons", []),
                    score=data.get("score", 0)
                )
            except json.JSONDecodeError:
                pass
        return RiskAssessment(level=RiskLevel.HIGH, reasons=["Invalid JSON from Sentinel"], score=100)
