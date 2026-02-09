import sys
import os
import time

# Add project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel
from tests.mock_nlu import MockNLUBridge, COMMON_MOCKS

def test_phase_10_temp_ops():
    mock_nlu = MockNLUBridge(COMMON_MOCKS)
    manager = ExecutionManager(nlu_bridge=mock_nlu)

    print("\n--- Phase 10: Temperature & Health Test (Category 10) ---")
    
    test_cases = [
        ("Sistem sıcaklıklarını göster", "get_system_temps"),
        ("CPU aşırı ısınıyor mu", "check_cpu_overheat"),
        ("GPU throttling var mı", "check_gpu_throttling"),
        ("Fan hızlarını göster", "get_fan_speeds"),
        ("Donanım uyarıları var mı", "check_hardware_warnings"),
        ("Isıdan kapanma riski var mı", "check_thermal_shutdown_risk")
    ]

    success_count = 0
    
    for user_input, expected_intent in test_cases:
        print(f"\nInput: '{user_input}'")
        try:
            intent, cmd, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"  -> Intent: {intent.intent_type}")
            print(f"  -> Target: {intent.target}")
            print(f"  -> Risk: {intent.risk}")
            
            if intent.intent_type == expected_intent:
                print(f"  -> CMD: {cmd}")
                success_count += 1
            else:
                print(f"  -> ERROR: Expected {expected_intent}, got {intent.intent_type}")
                
        except Exception as e:
            print(f"  -> EXCEPTION: {e}")
            import traceback
            traceback.print_exc()

    print("-" * 50)
    print(f"SONUÇ: {success_count} Başarılı, {len(test_cases) - success_count} Başarısız")
    
    if success_count == len(test_cases):
        print("\n>>> TÜM TESTLER BAŞARIYLA GEÇTİ! <<<")
        sys.exit(0)
    else:
        print("\n>>> BAZI TESTLER BAŞARISIZ OLDU! <<<")
        sys.exit(1)

if __name__ == "__main__":
    test_phase_10_temp_ops()
