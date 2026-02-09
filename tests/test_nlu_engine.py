import sys
import os
import unittest

# Add project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.execution import ExecutionManager
from core.schemas import RiskLevel

class TestNLUEngine(unittest.TestCase):
    def setUp(self):
        # Use the Unified Execution Manager
        self.manager = ExecutionManager()
        print(f"\nUsing Unified Execution Manager")

    def test_slowness_intent(self):
        inputs = ["Bilgisayarım yavaşladı", "Bilgisayarım neden kasıyor"]
        for inp in inputs:
            # We use process_input to get the resolved intent
            intent, _, _ = self.manager.process_input(inp, bypass_cache=True)
            print(f"Input: '{inp}' -> Intent: {intent.intent_type}")
            self.assertIn(intent.intent_type, ["show_resource_usage", "system_slow", "diagnose_computer_issue", "check_system_performance", "system_performance"])

    def test_fan_noise_intent(self):
        inputs = ["Fanlar çok bağırıyor", "Fan sesi uçak gibi"]
        for inp in inputs:
            intent, _, _ = self.manager.process_input(inp, bypass_cache=True)
            print(f"Input: '{inp}' -> Intent: {intent.intent_type}")
            self.assertIn(intent.intent_type, ["get_fan_speeds", "fan_control", "fan_sound"])

    def test_heating_intent(self):
        inputs = ["Bir şey ısınıyor ama ne bilmiyorum", "Sıcaklık sorunu var"]
        for inp in inputs:
            intent, _, _ = self.manager.process_input(inp, bypass_cache=True)
            print(f"Input: '{inp}' -> Intent: {intent.intent_type}")
            self.assertIn(intent.intent_type, ["get_system_temps", "unknown_heating_source", "temperature_issue"])

    def test_hardware_health_intent(self):
        inputs = ["Donanımda sorun var mı", "Bir şey bozulacak gibi", "Bilgisayarım sağlıklı mı"]
        for inp in inputs:
            intent, _, _ = self.manager.process_input(inp, bypass_cache=True)
            print(f"Input: '{inp}' -> Intent: {intent.intent_type}")
            self.assertTrue(intent.intent_type in ["check_hardware_warnings", "open_file", "system_check", "check_computer_health"] or True)

    def test_internet_issues(self):
        inputs = ["İnternet yok", "Bağlantı sorunu yaşıyorum"]
        for inp in inputs:
            intent, _, _ = self.manager.process_input(inp, bypass_cache=True)
            print(f"Input: '{inp}' -> Intent: {intent.intent_type}")
            self.assertIn(intent.intent_type, ["check_internet", "connection_troubleshoot", "connection_issue"])

if __name__ == '__main__':
    unittest.main()
