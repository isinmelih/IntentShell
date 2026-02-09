import re
from typing import Tuple

class RiskClassifier:
    """
    Classifies destructive commands into 'Routine' and 'Critical'.
    Routine: Safe-ish cleanups (temp files, cache, logs).
    Critical: Dangerous operations (system drives, format, deep recursive deletes).
    """
    
    ROUTINE_PATTERNS = [
        r'temp', r'tmp', r'cache', r'logs?', r'history',
        r'download', r'recycle\.bin', r'\.log$', r'\.tmp$', r'\.bak$'
    ]
    
    CRITICAL_PATTERNS = [
        r'[c-z]:\\windows', r'[c-z]:\\program files', r'[c-z]:\\users\\[^\\]+$',
        r'system32', r'format', r'diskpart', r'vssadmin',
        r'del\s+/s\s+/q\s+[c-z]:\\', r'rm\s+-rf\s+/'
    ]

    @staticmethod
    def classify_destructive(command: str) -> Tuple[str, float]:
        """
        Returns (Classification, RiskWeight).
        Routine = 0.5
        Critical = 2.0
        Default = 1.0
        """
        cmd_lower = command.lower()
        
        # Check Critical First
        for pattern in RiskClassifier.CRITICAL_PATTERNS:
            if re.search(pattern, cmd_lower):
                return "Critical Destructive", 2.0
                
        # Check Routine
        for pattern in RiskClassifier.ROUTINE_PATTERNS:
            if re.search(pattern, cmd_lower):
                return "Routine Destructive", 0.5
                
        return "Destructive", 1.0
