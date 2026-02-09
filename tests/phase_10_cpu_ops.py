import sys
import os
import time

# Add project root to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel
from tests.mock_nlu import MockNLUBridge, COMMON_MOCKS

def test_cpu_ops():
    print("\n>>> BAŞLIYOR: FAZ 10 - Kategori 2: CPU (İşlemci) Testleri <<<\n")
    
    # Use Mock NLU to avoid API rate limits and hanging commands
    mock_nlu = MockNLUBridge(COMMON_MOCKS)
    manager = ExecutionManager(nlu_bridge=mock_nlu)
    
    test_cases = [
        "İşlemci modeli nedir",
        "Kaç çekirdek var",
        "Kaç thread var",
        "Anlık CPU kullanımını göster",
        "Son 1 dakikalık CPU ortalaması",
        "En çok CPU kullanan uygulamalar",
        "CPU sıcaklığını göster",
        "CPU frekansını göster",
        "Turbo aktif mi",
        "CPU mimarisi nedir (x64 vs)"
    ]
    
    passed = 0
    failed = 0
    
    for i, user_input in enumerate(test_cases, 1):
        print(f"[{i}/{len(test_cases)}] Input: '{user_input}'")
        
        try:
            # New API: process_input returns (intent, command, risk)
            intent, cmd, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"  -> Intent: {intent.intent_type}")
            print(f"  -> Target: {intent.target}")
            print(f"  -> Risk: {intent.risk}")
            
            if intent.intent_type in ["unknown", "error"]:
                print("  -> FAILED: Intent not recognized")
                failed += 1
                continue
                
            if not cmd:
                print("  -> FAILED: No command generated")
                failed += 1
            else:
                print(f"  -> CMD: {cmd}")
                passed += 1
                
        except Exception as e:
            print(f"  -> ERROR: {e}")
            import traceback
            traceback.print_exc()
            failed += 1
        
        print("-" * 50)
        time.sleep(0.1)  # Simulate processing time
        
    print(f"\nSONUÇ: {passed} Başarılı, {failed} Başarısız")
    
    if failed == 0:
        print("\n>>> TÜM TESTLER BAŞARIYLA GEÇTİ! <<<")
        sys.exit(0)
    else:
        print(f"\n>>> {failed} TEST BAŞARISIZ OLDU! <<<")
        sys.exit(1)

if __name__ == "__main__":
    test_cpu_ops()
