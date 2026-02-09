import keyboard
import os
import time
import sys

def set_hotkey():
    print("\n--- IntentShell Hotkey Configuration ---")
    print("Press the desired hotkey combination now (e.g., Alt+Space, Ctrl+K)...")
    print("Press 'Esc' to cancel.")
    
    # Wait for a short moment to clear buffer
    time.sleep(0.5)
    
    try:
        # read_hotkey blocks until a hotkey is pressed
        hotkey = keyboard.read_hotkey(suppress=False)
        
        if hotkey == "esc":
            print("Cancelled.")
            return

        print(f"\nCaptured Hotkey: {hotkey}")
        
        # Save to config via ConfigManager logic
        # We import here to avoid circular dependency issues if any, or just use configparser directly
        import configparser
        
        config_dir = "config"
        config_path = os.path.join(config_dir, "main.ini")
        
        config = configparser.ConfigParser()
        if os.path.exists(config_path):
            config.read(config_path, encoding='utf-8')
            
        if not config.has_section("Hotkey"):
            config.add_section("Hotkey")
            
        config.set("Hotkey", "hotkey", hotkey)
        
        if not os.path.exists(config_dir):
            os.makedirs(config_dir)
            
        with open(config_path, "w", encoding="utf-8") as f:
            config.write(f)
            
        print(f"✅ Hotkey saved to {config_path}")
        print("Please restart IntentShell for changes to take effect.")
        
    except Exception as e:
        print(f"Error capturing hotkey: {e}")

if __name__ == "__main__":
    set_hotkey()
