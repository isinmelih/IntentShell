import sys
import os

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

def run_advanced_ops_test():
    manager = ExecutionManager()
    
    test_cases = [
        "Bu klasörü zip yap",
        "Zip dosyasını aç",
        "Dosya isimlerini küçük harfe çevir",
        "Dosya isimlerindeki boşlukları alt çizgi yap",
        "Tüm .txt dosyalarının içine 'backup' ekle",
        "Masaüstünü temizle",
        "Eski log dosyalarını sil",
        "Son bir ayda değişmeyen dosyaları bul",
        "Tüm alt klasörleri listele",
        "Dosya uzantılarına göre istatistik çıkar"
    ]
    
    passed = 0
    failed = 0
    
    print(f"Starting Phase 8 Advanced Ops Test - {len(test_cases)} cases")
    print("-" * 60)
    
    for i, user_input in enumerate(test_cases):
        print(f"\n[{i+1}/{len(test_cases)}] Input: '{user_input}'")
        
        try:
            intent, command, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"  -> Intent: {intent.intent_type}")
            print(f"  -> Target: {intent.target}")
            print(f"  -> Filters: {intent.filters}")
            
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
    run_advanced_ops_test()
