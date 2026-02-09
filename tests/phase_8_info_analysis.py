import sys
import os
import time

# Add core to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

def test_info_analysis():
    manager = ExecutionManager()
    
    test_cases = [
        "Bu klasörde kaç dosya var",
        "Toplam boyut ne kadar",
        "En eski dosya hangisi",
        "En yeni dosya hangisi",
        "Dosya türlerine göre dağılım çıkar",
        "Son 30 günde en çok değişen klasör hangisi"
    ]
    
    passed = 0
    failed = 0
    
    print("--- Phase 8: Info & Analysis Tests ---")
    for i, user_input in enumerate(test_cases):
        print(f"\n[{i+1}/{len(test_cases)}] Input: '{user_input}'")
        
        try:
            intent, cmd_result, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"  -> Intent: {intent.intent_type}")
            print(f"  -> Target: {intent.target}")
            print(f"  -> Filters: {intent.filters}")
            print(f"  -> Risk: {intent.risk}")
            
            if cmd_result and intent.intent_type not in ["unknown", "error"]:
                print(f"  -> CMD: {cmd_result}")
                passed += 1
            else:
                print(f"  -> CMD: NO COMMAND GENERATED")
                failed += 1
        except Exception as e:
            print(f"  -> ERROR: {e}")
            failed += 1
            
    print(f"\nSummary: {passed} Passed, {failed} Failed")
    if failed > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    test_info_analysis()
