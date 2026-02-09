import configparser
import os
import sys

CONFIG_DIR = "config"
CONFIG_FILE = os.path.join(CONFIG_DIR, "main.ini")

def load_config():
    config = configparser.ConfigParser()
    if os.path.exists(CONFIG_FILE):
        config.read(CONFIG_FILE, encoding='utf-8')
    return config

def save_config(config):
    if not os.path.exists(CONFIG_DIR):
        os.makedirs(CONFIG_DIR)
    with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
        config.write(f)

def set_value(section, key, value):
    config = load_config()
    if not config.has_section(section):
        config.add_section(section)
    config.set(section, key, str(value))
    save_config(config)
    print(f"[{section}] {key} = {value}")

def get_value(section, key, fallback=None):
    config = load_config()
    if config.has_option(section, key):
        return config.get(section, key)
    return fallback

def toggle_boolean(section, key):
    config = load_config()
    current_val = "false"
    if config.has_option(section, key):
        current_val = config.get(section, key).lower()
    
    new_val = "true" if current_val != "true" else "false"
    
    if not config.has_section(section):
        config.add_section(section)
    
    config.set(section, key, new_val)
    save_config(config)
    
    status = "ENABLED" if new_val == "true" else "DISABLED"
    print(f"[INFO] {section} {status}.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python config_manager.py <command> <args...>")
        sys.exit(1)
        
    command = sys.argv[1]
    
    if command == "toggle":
        if len(sys.argv) != 4:
            print("Usage: python config_manager.py toggle <section> <key>")
            sys.exit(1)
        toggle_boolean(sys.argv[2], sys.argv[3])
        
    elif command == "set":
        if len(sys.argv) != 5:
            print("Usage: python config_manager.py set <section> <key> <value>")
            sys.exit(1)
        set_value(sys.argv[2], sys.argv[3], sys.argv[4])

    elif command == "get":
        if len(sys.argv) != 4:
            print("Usage: python config_manager.py get <section> <key>")
            sys.exit(1)
        val = get_value(sys.argv[2], sys.argv[3])
        if val is not None:
            print(val)
