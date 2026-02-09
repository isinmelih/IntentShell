
import sys
import os

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

def test_disk_ops():
    print("--- Phase 10: Disk & Storage Ops Test ---\n")
    
    manager = ExecutionManager()
    
    test_cases = [
        "Diskleri listele",
        "SSD mi HDD mi",
        "Disk sağlık durumunu göster",
        "SMART bilgilerini göster",
        "Disk doluluk oranı",
        "En dolu disk hangisi",
        "Disk okuma yazma hızını göster",
        "En büyük klasörleri göster",
        "Disk seri numarasını göster",
        "Disk sıcaklığını göster"
    ]
    
    passed = 0
    failed = 0
    
    for i, user_input in enumerate(test_cases, 1):
        print(f"[{i}/{len(test_cases)}] Input: '{user_input}'")
        
        try:
            # 1. Process
            intent, cmd, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"   -> Intent: {intent.intent_type}")
            print(f"   -> Target: {intent.target}")
            print(f"   -> Filters: {intent.filters}")
            print(f"   -> Risk: {intent.risk}")
            
            # 2. Check Command
            if cmd:
                print(f"   -> Command: {cmd}")
                passed += 1
            else:
                if intent.intent_type in ["unknown", "error"]:
                    print("   -> FAILED: Intent not recognized")
                else:
                    print("   -> FAILED: No command generated.")
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
    test_disk_ops()
