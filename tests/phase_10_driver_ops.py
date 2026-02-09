
import sys
import os
import time

# Add project root to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

def test_driver_ops():
    print("\n>>> BAŞLIYOR: FAZ 10 - Kategori 8: Sürücüler & Drivers Testleri <<<\n")
    
    manager = ExecutionManager()
    
    test_cases = [
        ("Yüklü driver’ları listele", "list_drivers"),
        ("Güncel olmayan driver’ları bul", "get_outdated_drivers"),
        ("Ekran kartı driver sürümü", "get_gpu_driver_info"),
        ("Ses driver’ı sürümü", "get_audio_driver_info"),
        ("Bilinmeyen cihaz var mı", "check_unknown_devices"),
        ("Driver hatalarını göster", "get_driver_errors"),
        ("Donanım çakışması var mı", "check_hardware_conflicts")
    ]
    
    passed = 0
    failed = 0
    
    for i, (user_input, expected_intent) in enumerate(test_cases, 1):
        print(f"[{i}/{len(test_cases)}] Input: '{user_input}'")
        
        try:
            intent, cmd, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"  -> Intent: {intent.intent_type}")
            print(f"  -> Target: {intent.target}")
            print(f"  -> Risk: {intent.risk}")
            
            if intent.intent_type != expected_intent:
                print(f"  -> FAILED: Expected {expected_intent}, got {intent.intent_type}")
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
        time.sleep(0.1)
        
    print(f"\nSONUÇ: {passed} Başarılı, {failed} Başarısız")
    
    if failed == 0:
        print("\n>>> TÜM TESTLER BAŞARIYLA GEÇTİ! <<<")
        sys.exit(0)
    else:
        print(f"\n>>> {failed} TEST BAŞARISIZ OLDU! <<<")
        sys.exit(1)

if __name__ == "__main__":
    test_driver_ops()
