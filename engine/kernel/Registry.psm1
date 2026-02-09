
# IntentShell Registry Module
# Manages static intent definitions

$Global:IntentRegistry = @{}

function Register-Intent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Definition
    )
    
    $Global:IntentRegistry[$Name] = $Definition
}

function Get-RegisteredIntent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$UserInput
    )
    
    # Iterate through registry and find matching intent
    foreach ($key in $Global:IntentRegistry.Keys) {
        $def = $Global:IntentRegistry[$key]
        if ($def.Keywords) {
            foreach ($kw in $def.Keywords) {
                if ($UserInput -match $kw) {
                    Write-Verbose "Registry Hit: $key (Keyword: $kw)"
                    return $def
                }
            }
        }
    }
    
    return $null
}

# --- Network Category ---
Register-Intent -Name "check_internet" -Definition @{
    intent = "check_internet"
    description = "Check internet connection status"
    keywords = @("internet.*kontrol", "check.*internet", "internet.*yok")
    risk = "low"
    confirm_level = "none"
    command_template = "Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet"
}

Register-Intent -Name "get_ip_address" -Definition @{
    intent = "get_ip_address"
    description = "Show local IP address (IPv4)"
    keywords = @("ip.*göster", "ip.*address", "what.*is.*ip", "ip.*nedir")
    risk = "low"
    confirm_level = "none"
    command_template = 'Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback" -and $_.InterfaceAlias -notmatch "vEthernet" } | Select-Object InterfaceAlias, IPAddress, PrefixLength | Format-Table -AutoSize'
}

Register-Intent -Name "flush_dns" -Definition @{
    intent = "flush_dns"
    description = "Clear and reset the DNS client resolver cache"
    keywords = @("dns.*temizle", "flush.*dns", "dns.*sıfırla")
    risk = "medium"
    confirm_level = "none" # Medium risk but safe enough
    command_template = 'Clear-DnsClientCache; Write-Host "DNS Resolver Cache Flushed."'
}

Register-Intent -Name "renew_ip" -Definition @{
    intent = "renew_ip"
    description = "Release and renew IP address configuration"
    keywords = @("ip.*yenile", "renew.*ip", "bağlantı.*yenile")
    risk = "medium"
    confirm_level = "none"
    command_template = 'ipconfig /release; Start-Sleep -Seconds 2; ipconfig /renew'
}

Register-Intent -Name "show_wifi_profiles" -Definition @{
    intent = "show_wifi_profiles"
    description = "List all saved Wi-Fi profiles on the system"
    keywords = @("wifi.*listele", "wifi.*profiles", "kablosuz.*ağlar")
    risk = "low"
    confirm_level = "none"
    command_template = "netsh wlan show profiles"
}

# --- System General Info ---
Register-Intent -Name "get_system_specs" -Definition @{
    intent = "get_system_specs"
    description = "Get full system specifications"
    keywords = @("sistem.*özellikleri", "system.*specs", "bilgisayar.*özellikleri")
    risk = "low"
    confirm_level = "none"
    command_template = "Get-ComputerInfo | Select-Object CsName, CsManufacturer, CsModel, WindowsProductName, OsArchitecture, BiosSeralNumber, CsTotalPhysicalMemory | Format-List"
}

Register-Intent -Name "get_os_version" -Definition @{
    intent = "get_os_version"
    description = "Get Windows OS version"
    keywords = @("os.*version", "windows.*versiyon", "sürüm")
    risk = "low"
    confirm_level = "none"
    command_template = "Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture | Format-List"
}

Register-Intent -Name "get_uptime" -Definition @{
    intent = "get_uptime"
    description = "Show system uptime"
    keywords = @("uptime", "çalışma.*süresi", "ne.*kadar.*açık")
    risk = "low"
    confirm_level = "none"
    command_template = 'Get-CimInstance Win32_OperatingSystem | Select-Object @{Name="Uptime"; Expression={(Get-Date) - $_.LastBootUpTime}}'
}

# --- CPU ---
Register-Intent -Name "get_cpu_info" -Definition @{
    intent = "get_cpu_info"
    description = "Get CPU model, cores, threads"
    keywords = @("cpu.*bilgi", "işlemci.*özellikleri", "cpu.*info")
    risk = "low"
    confirm_level = "none"
    command_template = "Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | Format-List"
}

Register-Intent -Name "get_cpu_usage" -Definition @{
    intent = "get_cpu_usage"
    description = "Show current CPU usage percentage"
    keywords = @("cpu.*kullanım", "cpu.*usage", "işlemci.*yükü")
    risk = "low"
    confirm_level = "none"
    command_template = "Get-CimInstance Win32_Processor | Select-Object LoadPercentage | Format-List"
}

Register-Intent -Name "get_cpu_temp" -Definition @{
    intent = "get_cpu_temp"
    description = "Get CPU temperature (requires WMI/Admin)"
    keywords = @("cpu.*sıcaklık", "işlemci.*ısısı", "cpu.*temp")
    risk = "low"
    confirm_level = "none"
    command_template = 'Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction SilentlyContinue | Select-Object @{Name="Temperature(C)"; Expression={($_.CurrentTemperature - 2732) / 10.0}} | Format-Table -AutoSize'
}

# --- RAM ---
Register-Intent -Name "get_ram_info" -Definition @{
    intent = "get_ram_info"
    description = "Get RAM details"
    keywords = @("ram.*bilgi", "bellek.*özellikleri", "memory.*info")
    risk = "low"
    confirm_level = "none"
    command_template = "Get-CimInstance Win32_PhysicalMemory | Select-Object Manufacturer, PartNumber, Speed, Capacity, ConfiguredClockSpeed | Format-List"
}

Register-Intent -Name "get_ram_usage" -Definition @{
    intent = "get_ram_usage"
    description = "Show RAM usage stats"
    keywords = @("ram.*kullanım", "bellek.*durumu", "memory.*usage")
    risk = "low"
    confirm_level = "none"
    command_template = 'Get-CimInstance Win32_OperatingSystem | Select-Object @{Name="Total(GB)"; Expression={"{0:N2}" -f ($_.TotalVisibleMemorySize / 1MB)}}, @{Name="Free(GB)"; Expression={"{0:N2}" -f ($_.FreePhysicalMemory / 1MB)}}, @{Name="Used(GB)"; Expression={"{0:N2}" -f (($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) / 1MB)}} | Format-List'
}

# --- Disk ---
Register-Intent -Name "get_disk_info" -Definition @{
    intent = "get_disk_info"
    description = "Get physical disk info"
    keywords = @("disk.*bilgi", "hdd.*bilgi", "ssd.*bilgi")
    risk = "low"
    confirm_level = "none"
    command_template = 'Get-PhysicalDisk | Select-Object FriendlyName, MediaType, @{Name="Size(GB)"; Expression={"{0:N2}" -f ($_.Size / 1GB)}}, HealthStatus | Format-Table -AutoSize'
}

Register-Intent -Name "get_disk_usage" -Definition @{
    intent = "get_disk_usage"
    description = "Show disk usage per partition"
    keywords = @("disk.*doluluk", "yer.*durumu", "storage.*usage")
    risk = "low"
    confirm_level = "none"
    command_template = 'Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{Name="Used(GB)";Expression={"{0:N2}" -f ($_.Used/1GB)}}, @{Name="Free(GB)";Expression={"{0:N2}" -f ($_.Free/1GB)}} | Format-Table -AutoSize'
}

# --- GPU ---
Register-Intent -Name "get_gpu_info" -Definition @{
    intent = "get_gpu_info"
    description = "Get GPU model, VRAM"
    keywords = @("ekran.*kartı", "gpu.*info", "grafik.*kartı")
    risk = "low"
    confirm_level = "none"
    command_template = 'Get-CimInstance Win32_VideoController | Select-Object Name, VideoProcessor, AdapterDACType, @{Name="VRAM(GB)"; Expression={"{0:N2}" -f ($_.AdapterRAM / 1GB)}} | Format-List'
}

# --- Services ---
Register-Intent -Name "list_services" -Definition @{
    intent = "list_services"
    description = "List running system services"
    keywords = @("servisler", "services.*list", "çalışan.*servisler")
    risk = "low"
    confirm_level = "none"
    command_template = 'Get-Service | Where-Object {$_.Status -eq "Running"} | Select-Object Name, DisplayName, Status | Format-Table -AutoSize'
}

# --- System Operations ---
Register-Intent -Name "lock_screen" -Definition @{
    intent = "lock_screen"
    description = "Lock the workstation immediately"
    keywords = @("ekranı.*kilitle", "lock.*screen", "bilgisayarı.*kilitle")
    risk = "low"
    confirm_level = "none"
    command_template = 'rundll32.exe user32.dll,LockWorkStation'
}

Register-Intent -Name "shutdown_abort" -Definition @{
    intent = "shutdown_abort"
    description = "Abort a scheduled system shutdown"
    keywords = @("kapatmayı.*iptal", "abort.*shutdown", "kapanmayı.*durdur")
    risk = "low"
    confirm_level = "none"
    command_template = 'shutdown /a; Write-Host "Shutdown sequence aborted."'
}

# --- File Operations (Legacy/Simple) ---
Register-Intent -Name "list_files" -Definition @{
    intent = "list_files"
    description = "List files in directory"
    keywords = @("list.*files", "dosyaları.*listele", "^ls$")
    risk = "low"
    confirm_level = "none"
    command_template = "Get-ChildItem -Path ."
}

Export-ModuleMember -Function Register-Intent, Get-RegisteredIntent
