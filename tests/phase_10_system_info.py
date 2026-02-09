import sys
import os

# Add project root to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

def test_phase_10_system_info():
    print("\n>>> Starting Phase 10: System General Info Tests (System & Hardware - Category 1) <<<\n")
    
    manager = ExecutionManager()
    
    test_cases = [
        "Bilgisayarımın özelliklerini göster",
        "İşletim sistemi sürümünü söyle",
        "Windows build numarasını göster",
        "Bilgisayarın adını göster",
        "Bilgisayarın uptime süresini göster",
        "Son ne zaman yeniden başlatılmış",
        "Sistem dili nedir",
        "Sistem saat dilimini göster",
        "BIOS sürümünü göster",
        "Anakart modelini göster",
        "Cihaz seri numarasını göster"
    ]
    
    passed = 0
    failed = 0
    
    for i, user_input in enumerate(test_cases, 1):
        print(f"[{i}/{len(test_cases)}] Input: '{user_input}'")
        
        try:
            intent, cmd, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"  -> Intent: {intent.intent_type}")
            print(f"  -> Target: {intent.target}")
            print(f"  -> Risk: {intent.risk}")
            
            if cmd:
                print(f"  -> CMD: {cmd}")
                passed += 1
            else:
                print(f"  -> ERROR: No command generated for intent '{intent.intent_type}'")
                failed += 1
                
        except Exception as e:
            print(f"  -> ERROR: {e}")
            failed += 1
            
        print("-" * 50)

    print(f"\nSONUÇ: {passed} Başarılı, {failed} Başarısız")
    
    if failed == 0:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    test_phase_10_system_info()
