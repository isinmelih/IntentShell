from .schemas import Intent, RiskLevel

class CommandExplainer:
    @staticmethod
    def explain(intent: Intent, risk_assessment=None) -> str:
        """
        Returns a natural language explanation of the intent.
        Now includes Policy Reasons if available.
        """
        risk_emoji = "🟢"
        if intent.risk == RiskLevel.MEDIUM:
            risk_emoji = "⚠️"
        elif intent.risk in [RiskLevel.HIGH, RiskLevel.VERY_HIGH]:
            risk_emoji = "⛔"
            
        explanation = f"{risk_emoji} **{intent.description}**\n"
        explanation += f"Action: `{intent.intent_type}`\n"
        explanation += f"Target: `{intent.target}`\n"
        
        # Policy / Risk Explanation (Honesty Mode)
        if risk_assessment and risk_assessment.reasons:
            explanation += "\n🔍 **Policy Analysis:**\n"
            for reason in risk_assessment.reasons:
                explanation += f"  - {reason}\n"
        
        if intent.destination:
            explanation += f"Destination: `{intent.destination}`\n"
        if intent.filters:
            explanation += f"Filters: {', '.join(intent.filters)}\n"
        explanation += f"Recursive: {'Yes' if intent.recursive else 'No'}\n"
        
        return explanation
