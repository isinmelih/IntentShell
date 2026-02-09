import sys
import os

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel
from tests.mock_nlu import MockNLUBridge, COMMON_MOCKS

def test_hardware_ops():
    mock_nlu = MockNLUBridge(COMMON_MOCKS)
    manager = ExecutionManager(nlu_bridge=mock_nlu)
    
    test_cases = [
        "Takılı USB cihazları listele",
        "Bağlı yazıcıları göster",
        "Bluetooth cihazları listele",
        "Ses kartı bilgisi",
        "Kamera var mı",
        "Mikrofonları listele",
        "Touchpad aktif mi",
        "Pil var mı"
    ]
    
    passed = 0
    failed = 0
    
    print("Testing Phase 10: Hardware Components (Category 6)...")
    print("-" * 50)
    
    for i, input_text in enumerate(test_cases):
        print(f"[{i+1}/{len(test_cases)}] Input: '{input_text}'")
        
        try:
            intent, cmd, risk = manager.process_input(input_text, bypass_cache=True)
            
            print(f"   -> Intent: {intent.intent_type}")
            print(f"   -> Target: {intent.target}")
            print(f"   -> Filters: {intent.filters}")
            print(f"   -> Risk: {intent.risk}")
            
            if cmd:
                print(f"   -> Command: {cmd}")
                passed += 1
            else:
                print(f"   -> ERROR: No command generated for intent {intent.intent_type}")
                failed += 1
                
        except Exception as e:
            print(f"   -> ERROR: {e}")
            failed += 1
            
        print("-" * 50)
        
    print(f"\nTest Summary: {passed} Passed, {failed} Failed")
    if failed > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    test_hardware_ops()
