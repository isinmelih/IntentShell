
import sys
import os
sys.path.append(os.getcwd())

from core.user_profile import UserProfile

def verify_trust_system():
    # 1. Create/Load Profile
    profile = UserProfile()
    
    # Reset for test
    intent_type = "test_intent"
    profile.trusted_intents[intent_type] = 0
    profile.trust_level = 0.0
    
    print(f"Initial Trust Level: {profile.trust_level}")
    print(f"Initial Count for '{intent_type}': {profile.trusted_intents.get(intent_type, 0)}")
    
    # 2. Simulate 6 successes (Medium Trust Threshold > 5)
    print("\nSimulating 6 successes...")
    for _ in range(6):
        profile.record_success(intent_type, "low")
        
    mod = profile.get_trust_modifier(intent_type)
    print(f"Trust Modifier after 6 successes: {mod} (Expected: 0.1)")
    
    if mod != 0.1:
        print("FAIL: Expected 0.1 modifier")
    else:
        print("PASS: Modifier is 0.1")
        
    # 3. Simulate 5 more (Total 11, High Trust Threshold > 10)
    print("\nSimulating 5 more successes...")
    for _ in range(5):
        profile.record_success(intent_type, "low")
        
    mod = profile.get_trust_modifier(intent_type)
    print(f"Trust Modifier after 11 successes: {mod} (Expected: 0.3)")
    
    if mod != 0.3:
        print("FAIL: Expected 0.3 modifier")
    else:
        print("PASS: Modifier is 0.3")

    print(f"\nFinal Global Trust Level: {profile.trust_level}")

if __name__ == "__main__":
    verify_trust_system()
