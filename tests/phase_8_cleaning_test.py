import sys
import os

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

def run_cleaning_test():
    manager = ExecutionManager()
    
    test_cases = [
        "Geçici dosyaları temizle",
        "Çöp kutusunu boşalt",
        "Cache klasörlerini temizle",
        "Node projelerindeki node_modules klasörlerini sil",
        "Python projelerindeki __pycache__ klasörlerini sil"
    ]
    
    print(f"Starting Phase 8 Cleaning Test - {len(test_cases)} cases")
    print("-" * 60)
    
    passed = 0
    failed = 0
    
    for i, user_input in enumerate(test_cases):
        print(f"\n[{i+1}/{len(test_cases)}] Input: '{user_input}'")
        
        try:
            intent, command, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"  -> Intent: {intent.intent_type}")
            print(f"  -> Target: {intent.target}")
            print(f"  -> Risk: {intent.risk}")
            if hasattr(intent, 'confirm_level'):
                print(f"  -> Confirm: {intent.confirm_level}")
            
            if command and intent.intent_type not in ["unknown", "error"]:
                print(f"  -> CMD: {command}")
                passed += 1
            else:
                print(f"  -> GENERATE FAIL: {command or 'No command'}")
                failed += 1
                
        except Exception as e:
            print(f"  -> ERROR: {e}")
            failed += 1
            
    print("-" * 60)
    print(f"Summary: {passed} Passed, {failed} Failed")
    
    if failed > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    run_cleaning_test()
