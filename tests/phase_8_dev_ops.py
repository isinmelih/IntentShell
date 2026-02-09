import os
import sys

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

def test_phase_8_dev_ops():
    print("\n>>> Faz 8: Yazılım Geliştirme (Dev Ops) Testi Başlıyor... <<<\n")
    
    manager = ExecutionManager()
    
    test_cases = [
        "Git reposunun durumunu göster",
        "Son commit’leri listele",
        "Değişen dosyaları göster",
        "Tüm branch’leri listele",
        "feature-login adında yeni branch oluştur",
        "main branchine geçiş yap",
        "Tüm node projelerini bul",
        "Projelerde package.json olan klasörleri listele",
        "Tüm Python projelerini bul",
        "Virtual environment’ları listele",
        "Docker container’ları göster",
        "Çalışan tüm docker container’ları durdur",
        "Docker image’larını temizle",
        "8080 portunu kullanan process’i bul",
        "8080 portunu serbest bırak",
        "Projeyi build et",
        "Testleri çalıştır",
        "Lint çalıştır"
    ]
    
    passed = 0
    failed = 0
    
    for i, user_input in enumerate(test_cases, 1):
        print(f"\n[{i}/{len(test_cases)}] Input: '{user_input}'")
        
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
                print(f"  -> CMD: NO COMMAND GENERATED for intent: {intent.intent_type}")
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
    test_phase_8_dev_ops()
