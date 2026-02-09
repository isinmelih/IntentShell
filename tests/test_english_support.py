import unittest
import os
import sys

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import Intent, RiskLevel

class TestEnglishSupport(unittest.TestCase):
    def setUp(self):
        self.manager = ExecutionManager()

    def test_phase9_symptom_english(self):
        """Test English inputs for Phase 9 NLU/Symptom commands"""
        test_cases = [
            ("Computer is slow", "show_resource_usage"),
            ("Why is it lagging", "show_resource_usage"),
            ("Loud fan", "get_fan_speeds"),
            ("Fan noise", "get_fan_speeds"),
            ("Something is heating", "get_system_temps"),
            ("Is my computer healthy", "run_full_diagnostics"),
            ("No internet", "check_internet"),
            ("Connection issue", "check_internet"),
            ("Desktop is messy", "organize_desktop_smart"),
            ("Clean junk", "clean_all_junk"),
            ("Deep cleanup", "deep_system_cleanup")
        ]

        for user_input, expected_intent in test_cases:
            # We use bypass_cache=True to force NLU resolution (though without API it might use regex/fallback)
            intent, _, _ = self.manager.process_input(user_input, bypass_cache=True)
            
            # Since exact intent matching might depend on specific NLU training or regex, 
            # we accept if it resolves to something reasonable or fallback if the exact intent is not guaranteed without API.
            # However, for this test we try to match expected.
            # If NLU is not connected/mocked, it might return 'unknown' or fallback.
            # For now, we print and assert, but allow some flexibility if the system uses AI.
            
            print(f"Input: '{user_input}' -> Intent: {intent.intent_type}")
            
            # Note: Some intents might map differently in the new NLU bridge compared to old mock.
            # Updating assertions to match probable new mappings if they fail, but starting with strict check.
            self.assertEqual(intent.intent_type, expected_intent, f"Failed for input: {user_input}")

    def test_phase10_system_english(self):
        """Test English inputs for Phase 10 System/Hardware commands"""
        test_cases = [
            # CPU
            ("Show cpu model", "get_cpu_info"),
            ("How many cores", "get_cpu_info"),
            ("Cpu usage", "get_cpu_usage"),
            ("Cpu temp", "get_cpu_temp"),
            
            # RAM
            ("Total ram", "get_ram_info"),
            ("Used ram", "get_ram_usage"),
            ("Free ram", "get_ram_usage"),
            ("Ram speed", "get_ram_speed"),
            
            # Disk
            ("List disks", "get_disk_info"),
            ("Disk health", "get_disk_health"),
            ("Fullest disk", "get_disk_usage"),
            ("Largest folder", "find_large_items"),
            
            # GPU
            ("Graphics card model", "get_gpu_info"),
            ("Gpu usage", "get_gpu_usage"),
            ("Gpu temp", "get_gpu_temp"),
            
            # Drivers & Devices
            ("List drivers", "list_drivers"),
            ("Outdated drivers", "get_outdated_drivers"),
            ("List printers", "get_printers"),
            ("Battery status", "get_battery_status"),
            
            # Power
            ("Power plan", "get_power_plan"),
            ("High performance", "set_power_plan"),
            ("Turn off screen", "turn_off_screen"),
            
            # Services
            ("List services", "list_services"),
            ("Stop service Spooler", "stop_service"),
            
            # Virtualization
            ("Check virtualization", "check_virtualization_enabled"),
            ("List wsl distros", "list_wsl_distros")
        ]

        for user_input, expected_intent in test_cases:
            intent, _, _ = self.manager.process_input(user_input, bypass_cache=True)
            print(f"Input: '{user_input}' -> Intent: {intent.intent_type}")
            self.assertEqual(intent.intent_type, expected_intent, f"Failed for input: {user_input}")

if __name__ == '__main__':
    unittest.main()
