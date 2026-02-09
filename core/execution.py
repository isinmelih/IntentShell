import unicodedata
from typing import Optional, Tuple, Any, List
from .powershell_session import PowerShellSession
from .bridge_nlu import NLUBridge
from .bridge_dispatch import DispatchBridge
from .bridge_runner import RunnerBridge
from .bridge_sentinel import SentinelBridge
from .schemas import Intent, RiskLevel

class ExecutionResult:
    def __init__(self, success: bool, output: str, intent: Optional[Intent] = None, risk_assessment: Any = None):
        self.success = success
        self.output = output
        self.intent = intent
        self.risk_assessment = risk_assessment

class ExecutionManager:
    """
    Unified Entry Point for IntentShell Execution.
    Ensures consistency between UI and Tests.
    """
    def __init__(self, session: Optional[PowerShellSession] = None, nlu_bridge: Any = None):
        self.session = session or PowerShellSession()
        self.nlu = nlu_bridge or NLUBridge(self.session)
        self.dispatcher = DispatchBridge(self.session)
        self.sentinel = SentinelBridge(self.session)
        
    def normalize(self, text: str) -> str:
        """
        Standard input normalization.
        Applies Trim, Unicode Normalization (NFC), and removes invisible characters.
        """
        if not text: return ""
        # 1. Trim whitespace
        text = text.strip()
        # 2. Unicode Normalization (Form C)
        text = unicodedata.normalize('NFC', text)
        # 3. Handle Invisible Chars (Zero-width space \u200b)
        text = text.replace('\u200b', '')
        return text

    def process_input(self, raw_input: str, bypass_cache: bool = False) -> Tuple[Intent, str, Any]:
        """
        Standardized Pipeline: Normalize -> Parse -> Dispatch -> Assess
        Returns: (Intent, Command, RiskAssessment)
        """
        # 1. Normalize
        normalized = self.normalize(raw_input)
        
        # 2. Parse (Resolve Intent)
        intent = self.nlu.resolve_intent(normalized, bypass_cache=bypass_cache)
        
        # 3. Generate Command
        command = self.dispatcher.get_safe_command(intent)
        
        # 4. Assess Risk
        risk = self.sentinel.assess(intent, command)
        
        return intent, command, risk

    def execute_directly(self, raw_input: str, bypass_cache: bool = False) -> ExecutionResult:
        """
        Executes the input directly (Golden Path for Tests).
        Skips confirmation! Use only for tests or trusted inputs.
        """
        intent, command, risk = self.process_input(raw_input, bypass_cache)
        
        if intent.intent_type in ["unknown", "error", "kernel_error"]:
             return ExecutionResult(False, f"Intent Resolution Failed: {intent.description}", intent, risk)

        # Capture output
        logs = []
        def log_func(msg, style="info"):
            logs.append(msg)
            
        runner = RunnerBridge(log_func, session=self.session)
        
        try:
            success = runner.execute(command, intent)
            return ExecutionResult(success, "\n".join(logs), intent, risk)
        except Exception as e:
            return ExecutionResult(False, str(e), intent, risk)
