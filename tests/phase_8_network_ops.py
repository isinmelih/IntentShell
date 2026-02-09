import os
import sys

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

def test_phase_8_network_ops():
    """
    Test 10 Network & Internet operations from Phase 8.
    """
    manager = ExecutionManager()
    
    test_cases = [
        "İnternet bağlantım var mı kontrol et",
        "IP adresimi göster",
        "Açık portları listele",
        "Hangi program internete bağlanıyor göster",
        "DNS önbelleğini temizle",
        "Ping testi yap",
        "Google’a ping at",
        "En yavaş ağ bağlantılarını göster",
        "Wi-Fi bilgilerini göster",
        "Kaydedilmiş Wi-Fi şifrelerini listele"
    ]
    
    passed = 0
    failed = 0
    
    print("\nStarting Phase 8 Network Ops Test - 10 cases")
    print("-" * 60)
    
    for i, user_input in enumerate(test_cases, 1):
        print(f"\n[{i}/10] Input: '{user_input}'")
        
        try:
            intent, cmd_result, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"  -> Intent: {intent.intent_type}")
            print(f"  -> Target: {intent.target}")
            print(f"  -> Filters: {intent.filters}")
            
            if cmd_result and intent.intent_type not in ["unknown", "error"]:
                print(f"  -> CMD: {cmd_result}")
                passed += 1
            else:
                print(f"  -> CMD: NO COMMAND GENERATED (Adapter not found?)")
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
    test_phase_8_network_ops()
