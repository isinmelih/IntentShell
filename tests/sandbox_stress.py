import sys
import os
import time

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

def run_stress_test():
    manager = ExecutionManager()
    
    test_cases = [
        # Resource / System Info
        "List top 10 apps using the most GPU",
        "Show me system uptime",
        "Check available disk space on C drive",
        "What is my IP address?",
        "List all running python processes",
        
        # File Operations (Already supported, checking regression)
        "Create a file named hello.txt",
        "Delete all tmp files in downloads",
        
        # Network
        "Ping google.com",
        "Show active network connections",
        
        # Process Management
        "Kill process chrome",
        "Start notepad",
        
        # Creative / Abstract
        "Tell me a joke", # Should probably fail or be handled by a 'chat' intent
        "Clear the screen",
        "Show current date and time"
    ]
    
    print(f"Starting Sandbox Stress Test - {len(test_cases)} cases")
    print("-" * 60)
    
    passed = 0
    failed = 0
    
    for i, user_input in enumerate(test_cases):
        print(f"\n[{i+1}/{len(test_cases)}] Input: '{user_input}'")
        
        try:
            intent, command, risk = manager.process_input(user_input, bypass_cache=True)
            
            print(f"  -> Intent: {intent.intent_type}")
            
            if command and intent.intent_type not in ["unknown", "error"]:
                print(f"  -> SUCCESS: {command}")
                passed += 1
            else:
                print(f"  -> GENERATE FAIL: {command or 'No command'}")
                failed += 1
                
        except Exception as e:
            print(f"  -> ERROR: {e}")
            failed += 1
            
    print("-" * 60)
    print(f"Test Complete. Passed: {passed}, Failed: {failed}")
    if failed > 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    run_stress_test()
