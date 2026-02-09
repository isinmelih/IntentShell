import re
from typing import List, Tuple
from ..schemas import Intent, RiskAssessment, RiskLevel

class AntiPatternDetector:
    """
    Detects suspicious patterns that might indicate an attempt to bypass security or abuse the system.
    """
    
    OBFUSCATION_PATTERNS = [
        (r'\^', "Caret Obfuscation (cmd.exe style)"),
        (r'%.+%', "Variable Expansion Obfuscation"),
        (r'\$env:\w+', "Environment Variable Access"),
        (r'\[char\]', "Char Casting Obfuscation"),
        (r'base64', "Base64 Encoding"),
        (r'-enc\s+', "Encoded Command Execution"),
        (r'invoke-expression', "Invoke-Expression (IEX) Usage"),
        (r'iex\s+', "IEX Alias Usage"),
        (r'downloadstring', "Web Download Attempt"),
        (r'hidden', "Hidden Window Attempt"),
        (r'bypass', "Execution Policy Bypass Attempt")
    ]

    CHAINING_PATTERNS = [
        (r';', "Command Chaining (Semicolon)"),
        (r'&', "Command Chaining (Ampersand)"),
        (r'\|', "Pipeline Chaining")
    ]

    @staticmethod
    def scan(command: str) -> List[str]:
        """
        Scans a command string for known anti-patterns.
        Returns a list of detected suspicious reasons.
        """
        if not command:
            return []
            
        detections = []
        cmd_lower = command.lower()
        
        # 1. Check Obfuscation
        for pattern, reason in AntiPatternDetector.OBFUSCATION_PATTERNS:
            if re.search(pattern, cmd_lower):
                detections.append(f"Suspicious Pattern Detected: {reason}")
                
        # 2. Check Chaining Abuse (Excessive chaining)
        # Simple chaining is allowed, but excessive is suspicious
        semicolon_count = cmd_lower.count(';')
        pipe_count = cmd_lower.count('|')
        
        if semicolon_count > 2:
            detections.append(f"Excessive Chaining Detected ({semicolon_count} commands)")
            
        if pipe_count > 3:
            detections.append(f"Complex Pipeline Detected ({pipe_count} pipes)")
            
        # 3. Length Heuristic
        # Very long commands are often malicious payloads
        if len(command) > 1000:
            detections.append("Command Length Exceeds Safety Threshold (>1000 chars)")
            
        return detections
