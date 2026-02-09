
from typing import Optional
from core.schemas import Intent, RiskLevel

class MockNLUBridge:
    def __init__(self, mocks: dict):
        self.mocks = mocks

    def resolve_intent(self, user_input: str, bypass_cache: bool = False) -> Intent:
        # Normalize mock keys and input for better matching
        normalized_input = user_input.strip()
        
        if normalized_input in self.mocks:
            return self.mocks[normalized_input]
        
        # Default fallback for unknown mock
        return Intent(
            intent_type="unknown",
            target="system",
            risk=RiskLevel.LOW,
            description=f"Mock: Intent not found for '{user_input}'"
        )

# Define common mock intents for tests
COMMON_MOCKS = {
    # --- CPU Ops ---
    "İşlemci modeli nedir": Intent(
        intent_type="get_cpu_model", 
        target="CPU", 
        risk=RiskLevel.LOW, 
        generated_command="(Get-WmiObject -Class Win32_Processor).Name"
    ),
    "Kaç çekirdek var": Intent(
        intent_type="get_cpu_info", 
        target="CPU", 
        risk=RiskLevel.LOW, 
        generated_command="(Get-WmiObject -Class Win32_Processor).NumberOfCores"
    ),
    "Kaç thread var": Intent(
        intent_type="get_cpu_info", 
        target="CPU", 
        risk=RiskLevel.LOW, 
        generated_command="(Get-WmiObject -Class Win32_Processor).NumberOfLogicalProcessors"
    ),
    "Anlık CPU kullanımını göster": Intent(
        intent_type="get_cpu_usage", 
        target="system", 
        risk=RiskLevel.LOW, 
        generated_command="Get-CimInstance Win32_Processor | Select-Object LoadPercentage | Format-List"
    ),
    "Son 1 dakikalık CPU ortalaması": Intent(
        intent_type="get_cpu_average", 
        target="CPU", 
        risk=RiskLevel.LOW, 
        generated_command="(Get-Counter -Counter '\\Processor(_Total)\\% Processor Time' -SampleInterval 1 -MaxSamples 5).CounterSamples.CookedValue | Measure-Object -Average | Select-Object -ExpandProperty Average"
    ),
    "En çok CPU kullanan uygulamalar": Intent(
        intent_type="get_cpu_intensive_processes", 
        target="processes", 
        risk=RiskLevel.LOW, 
        generated_command="Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 10"
    ),
    "CPU sıcaklığını göster": Intent(
        intent_type="show_cpu_temperature", 
        target="CPU", 
        risk=RiskLevel.LOW, 
        generated_command="Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace root\\wmi | Select-Object -Property CurrentTemperature"
    ),
    "CPU frekansını göster": Intent(
        intent_type="show_cpu_frequency", 
        target="CPU", 
        risk=RiskLevel.LOW, 
        generated_command="(Get-WmiObject -Class Win32_Processor).CurrentClockSpeed"
    ),
    "Turbo aktif mi": Intent(
        intent_type="Check_Turbo_Mode", 
        target="System", 
        risk=RiskLevel.LOW, 
        generated_command="Write-Output 'Turbo Mode Check Not Implemented directly via WMI'"
    ),
    "CPU mimarisi nedir (x64 vs)": Intent(
        intent_type="CPU_Architecture", 
        target="CPU", 
        risk=RiskLevel.LOW, 
        generated_command="(Get-WmiObject -Class Win32_Processor).Architecture"
    ),

    # --- Service Ops ---
    "Çalışan servisleri listele": Intent(
        intent_type="list_services",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-Service | Where-Object {$_.Status -eq 'Running'}"
    ),
    "Otomatik başlayan servisler": Intent(
        intent_type="list_startup_services",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-WmiObject Win32_Service | Where-Object {$_.StartMode -eq 'Auto'}"
    ),
    "En çok CPU kullanan servis": Intent(
        intent_type="get_top_cpu_service",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-Process | Sort-Object CPU -Descending | Select-Object -First 1"
    ),
    "Spooler servisini durdur": Intent(
        intent_type="stop_service",
        target="Spooler",
        risk=RiskLevel.MEDIUM,
        generated_command="Stop-Service -Name Spooler -Force -PassThru"
    ),
    "OldService servisini sil": Intent(
        intent_type="delete_service",
        target="OldService",
        risk=RiskLevel.HIGH,
        generated_command="Write-Warning 'Service deletion mocked for safety'"
    ),
    "Spooler servisini yeniden başlat": Intent(
        intent_type="restart_service",
        target="Spooler",
        risk=RiskLevel.MEDIUM,
        generated_command="Restart-Service -Name Spooler -Force -PassThru"
    ),
    "Servis durumunu kontrol et": Intent(
        intent_type="get_service_status",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-Service"
    ),
    "Askıda kalan process’leri bul": Intent(
        intent_type="find_hung_processes",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-Process | Where-Object {$_.Responding -eq $false}"
    ),
    "Uygulamayı zorla kapat": Intent(
        intent_type="force_kill_process",
        target="application",
        risk=RiskLevel.HIGH,
        generated_command="Write-Warning 'Kill process mocked'"
    ),

    # --- RAM Ops ---
    "Toplam RAM ne kadar": Intent(
        intent_type="get_total_ram",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="(Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB"
    ),
    "Kullanılan RAM miktarı": Intent(
        intent_type="get_ram_usage",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"
    ),
    "Boş RAM miktarı": Intent(
        intent_type="get_ram_usage",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory"
    ),
    "RAM kullanım yüzdesi": Intent(
        intent_type="get_ram_usage",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-CimInstance Win32_OperatingSystem | Select-Object @{Name='Used%';Expression={($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)/$_.TotalVisibleMemorySize * 100}}"
    ),
    "RAM tipi nedir (DDR4, DDR5)": Intent(
        intent_type="get_ram_info",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-CimInstance Win32_PhysicalMemory | Select-Object PartNumber, Speed"
    ),
    "RAM frekansı kaç MHz": Intent(
        intent_type="get_ram_info",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-CimInstance Win32_PhysicalMemory | Select-Object Speed"
    ),
    "Kaç slot dolu": Intent(
        intent_type="get_ram_slots",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-CimInstance Win32_PhysicalMemory | Measure-Object | Select-Object Count"
    ),
    "Hangi uygulama RAM yiyor": Intent(
        intent_type="get_top_ram_consumers",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 5"
    ),
    "RAM hatası var mı": Intent(
        intent_type="check_ram_errors",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Write-Output 'No memory errors detected (Mock)'"
    ),
    "Bellek sızıntısı yapan uygulamalar": Intent(
        intent_type="detect_memory_leaks",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Write-Output 'Memory leak detection not implemented'"
    ),

    # --- Hardware Ops ---
    "Takılı USB cihazları listele": Intent(
        intent_type="list_usb_devices",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^USB' }"
    ),
    "Bağlı yazıcıları göster": Intent(
        intent_type="list_printers",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-Printer"
    ),
    "Bluetooth cihazları listele": Intent(
        intent_type="list_bluetooth_devices",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-PnpDevice -PresentOnly | Where-Object { $_.Class -eq 'Bluetooth' }"
    ),
    "Ses kartı bilgisi": Intent(
        intent_type="get_audio_info",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-PnpDevice -PresentOnly | Where-Object { $_.Class -eq 'AudioEndpoint' }"
    ),
    "Kamera var mı": Intent(
        intent_type="check_camera",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-PnpDevice -PresentOnly | Where-Object { $_.Class -eq 'Camera' -or $_.Class -eq 'Image' }"
    ),
    "Mikrofonları listele": Intent(
        intent_type="list_microphones",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-PnpDevice -PresentOnly | Where-Object { $_.Class -eq 'AudioEndpoint' }"
    ),
    "Touchpad aktif mi": Intent(
        intent_type="check_touchpad",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match 'Touchpad' }"
    ),
    "Pil var mı": Intent(
        intent_type="check_battery",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="Get-WmiObject Win32_Battery"
    ),

    # --- Power Ops ---
    "Pil durumu yüzde kaç": Intent(
        intent_type="get_battery_status",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="(Get-WmiObject Win32_Battery).EstimatedChargeRemaining"
    ),
    "Pil sağlığı": Intent(
        intent_type="get_battery_health",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="powercfg /batteryreport /output 'battery_report.html'"
    ),
    "Şarj oluyor mu": Intent(
        intent_type="check_charging_status",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="(Get-WmiObject Win32_Battery).BatteryStatus"
    ),
    "Tahmini kalan süre": Intent(
        intent_type="get_battery_time_remaining",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="(Get-WmiObject Win32_Battery).EstimatedRunTime"
    ),
    "Güç planı hangisi": Intent(
        intent_type="get_power_plan",
        target="system",
        risk=RiskLevel.LOW,
        generated_command="powercfg /getactivescheme"
    ),
    "Yüksek performans moduna geç": Intent(
        intent_type="set_power_plan",
        target="High Performance",
        risk=RiskLevel.MEDIUM,
        generated_command="powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    ),
    "Güç tasarrufuna geç": Intent(
        intent_type="set_power_plan",
        target="Power Saver",
        risk=RiskLevel.MEDIUM,
        generated_command="powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a"
    ),
    "Uyku moduna al": Intent(
        intent_type="sleep_computer",
        target="system",
        risk=RiskLevel.HIGH,
        generated_command="rundll32.exe powrprof.dll,SetSuspendState 0,1,0"
    ),
    "Hazırda beklet": Intent(
        intent_type="hibernate_computer",
        target="system",
        risk=RiskLevel.HIGH,
        generated_command="shutdown /h"
    ),
    # --- Virt Ops ---
    "Sanallaştırma açık mı": Intent(
        intent_type="check_virtualization_enabled",
        target="system",
        risk=RiskLevel.LOW,
        description="Check if virtualization is enabled",
        generated_command="(Get-WmiObject -Class Win32_Processor).VirtualizationFirmwareEnabled"
    ),
    "Hyper-V aktif mi": Intent(
        intent_type="check_hyperv_status",
        target="system",
        risk=RiskLevel.LOW,
        description="Check Hyper-V status",
        generated_command="Get-Service vmms"
    ),
    "WSL kurulu mu": Intent(
        intent_type="check_wsl_installed",
        target="system",
        risk=RiskLevel.LOW,
        description="Check if WSL is installed",
        generated_command="wsl --status"
    ),
    "WSL dağıtımlarını listele": Intent(
        intent_type="list_wsl_distros",
        target="system",
        risk=RiskLevel.LOW,
        description="List WSL distros",
        generated_command="wsl --list --verbose"
    ),
    "BIOS’ta sanallaştırma açık mı": Intent(
        intent_type="check_bios_virtualization",
        target="system",
        risk=RiskLevel.LOW,
        description="Check BIOS virtualization setting",
        generated_command="(Get-WmiObject -Class Win32_ComputerSystem).HypervisorPresent"
    ),
    "Secure Boot durumu": Intent(
        intent_type="check_secure_boot",
        target="system",
        risk=RiskLevel.LOW,
        description="Check Secure Boot status",
        generated_command="Confirm-SecureBootUEFI"
    ),

    # --- Temp Ops ---
    "Sistem sıcaklıklarını göster": Intent(
        intent_type="get_system_temps",
        target="system",
        risk=RiskLevel.LOW,
        description="Show system temperatures",
        generated_command="Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace root/wmi"
    ),
    "CPU aşırı ısınıyor mu": Intent(
        intent_type="check_cpu_overheat",
        target="system",
        risk=RiskLevel.LOW,
        description="Check for CPU overheating",
        generated_command="Write-Output 'Checking CPU temp thresholds...'"
    ),
    "GPU throttling var mı": Intent(
        intent_type="check_gpu_throttling",
        target="system",
        risk=RiskLevel.LOW,
        description="Check for GPU throttling",
        generated_command="Write-Output 'GPU throttling check not available'"
    ),
    "Fan hızlarını göster": Intent(
        intent_type="get_fan_speeds",
        target="system",
        risk=RiskLevel.LOW,
        description="Show fan speeds",
        generated_command="Get-WmiObject Win32_Fan"
    ),
    "Donanım uyarıları var mı": Intent(
        intent_type="check_hardware_warnings",
        target="system",
        risk=RiskLevel.LOW,
        description="Check for hardware warnings",
        generated_command="Get-EventLog -LogName System -EntryType Warning,Error -Source *Hardware* -Newest 10"
    ),
    "Isıdan kapanma riski var mı": Intent(
        intent_type="check_thermal_shutdown_risk",
        target="system",
        risk=RiskLevel.LOW,
        description="Check thermal shutdown risk",
        generated_command="Write-Output 'Thermal risk analysis...'"
    )
}
