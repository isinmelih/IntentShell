import json
import os
from datetime import datetime
from typing import List, Dict

PROFILE_PATH = "config/user_profile.json"

class UserProfile:
    def __init__(self):
        self.trust_level: float = 0.0 # 0.0 to 1.0
        self.command_history: List[Dict] = []
        self.trusted_intents: Dict[str, int] = {} # intent_type -> count
        self._load()

    def _load(self):
        if os.path.exists(PROFILE_PATH):
            try:
                with open(PROFILE_PATH, "r") as f:
                    data = json.load(f)
                    self.trust_level = data.get("trust_level", 0.0)
                    self.command_history = data.get("command_history", [])
                    self.trusted_intents = data.get("trusted_intents", {})
            except Exception as e:
                print(f"Error loading profile: {e}")

    def _save(self):
        try:
            os.makedirs(os.path.dirname(PROFILE_PATH), exist_ok=True)
            data = {
                "trust_level": self.trust_level,
                "command_history": self.command_history[-100:], # Keep last 100
                "trusted_intents": self.trusted_intents
            }
            with open(PROFILE_PATH, "w") as f:
                json.dump(data, f, indent=4)
        except Exception as e:
            print(f"Error saving profile: {e}")

    def record_success(self, intent_type: str, risk_level: str, user_input: str = ""):
        """
        Updates profile after a successful command execution.
        """
        # Update history
        self.command_history.append({
            "timestamp": datetime.now().isoformat(),
            "intent": intent_type,
            "risk": risk_level,
            "user_input": user_input,
            "status": "success"
        })
        
        # Update trust count for this intent
        self.trusted_intents[intent_type] = self.trusted_intents.get(intent_type, 0) + 1
        
        # Increase global trust level slightly
        # Cap at 1.0
        increment = 0.01
        if risk_level == "medium":
            increment = 0.05
        elif risk_level == "high":
            increment = 0.1 # Successful high risk ops build more trust
            
        self.trust_level = min(1.0, self.trust_level + increment)
        self._save()

    def get_recent_history(self, limit: int = 5) -> List[Dict]:
        """Returns the last N successful commands."""
        return self.command_history[-limit:]

    def get_trust_modifier(self, intent_type: str) -> float:
        """
        Returns a trust modifier based on history.
        High trust might lower the risk confirmation barrier.
        """
        count = self.trusted_intents.get(intent_type, 0)
        
        # If user did this 10+ times, we trust them more with this specific action
        if count > 10:
            return 0.3 # 30% reduction in risk sensitivity
        elif count > 5:
            return 0.1
            
        return 0.0
