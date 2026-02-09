using module .\SystemCore.psm1

# IntentShell Media Operations Module
# Provides capabilities to manage Audio and Display Brightness
# Capabilities: Volume Up/Down/Mute, Brightness Control

# Compile C# P/Invoke wrapper for User32.dll (SendInput/SendMessage)
$MediaCode = @"
using System;
using System.Runtime.InteropServices;

public class MediaManager {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    public const int VK_VOLUME_MUTE = 0xAD;
    public const int VK_VOLUME_DOWN = 0xAE;
    public const int VK_VOLUME_UP = 0xAF;
    public const int VK_MEDIA_NEXT_TRACK = 0xB0;
    public const int VK_MEDIA_PREV_TRACK = 0xB1;
    public const int VK_MEDIA_PLAY_PAUSE = 0xB3;

    public static void VolumeUp() {
        keybd_event((byte)VK_VOLUME_UP, 0, 0, UIntPtr.Zero);
    }

    public static void VolumeDown() {
        keybd_event((byte)VK_VOLUME_DOWN, 0, 0, UIntPtr.Zero);
    }

    public static void Mute() {
        keybd_event((byte)VK_VOLUME_MUTE, 0, 0, UIntPtr.Zero);
    }
    
    public static void PlayPause() {
        keybd_event((byte)VK_MEDIA_PLAY_PAUSE, 0, 0, UIntPtr.Zero);
    }
}
"@

try {
    Add-Type -TypeDefinition $MediaCode -Language CSharp -ErrorAction Stop
} catch {
    Write-Verbose "MediaManager already loaded."
}

function Set-Volume {
    param([string]$Action) # Up, Down, Mute
    
    switch ($Action.ToLower()) {
        "up" { [MediaManager]::VolumeUp(); Write-Output "Volume Increased." }
        "down" { [MediaManager]::VolumeDown(); Write-Output "Volume Decreased." }
        "mute" { [MediaManager]::Mute(); Write-Output "Volume Muted/Unmuted." }
        "playpause" { [MediaManager]::PlayPause(); Write-Output "Media Play/Pause Toggled." }
    }
}

function Set-Brightness {
    param([int]$Level) # 0-100
    
    # Use WMI for brightness
    try {
        $monitor = Get-WmiObject -Namespace root/wmi -Class WmiMonitorBrightnessMethods
        $monitor.WmiSetBrightness(1, $Level)
        Write-Output "Screen brightness set to $Level%."
    } catch {
        Write-Warning "Failed to set brightness. This feature may not be supported on this monitor/device."
    }
}

function Get-Screenshot {
    param([string]$Path = "$env:USERPROFILE\Pictures\IntentShell_Capture_$(Get-Date -Format 'yyyyMMdd_HHmmss').png")

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    
    $graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
    
    $bitmap.Save($Path)
    $graphics.Dispose()
    $bitmap.Dispose()
    
    Write-Output "Screenshot saved to: $Path"
}

class MediaOperationsModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    MediaOperationsModule() {
        $this.Name = "MediaOperations"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'ReadWrite'
        $this.Description = "Media Control Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Media:Volume" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Media:Volume requires Action argument.") }
                    Set-Volume -Action $Plan.Arguments[0]
                    return [ModuleResult]::new($true, "Volume Action Executed")
                }
                "Media:Brightness" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Media:Brightness requires Level argument.") }
                    Set-Brightness -Level ([int]$Plan.Arguments[0])
                    return [ModuleResult]::new($true, "Brightness Action Executed")
                }
                "Media:Screenshot" {
                    $path = if ($Plan.Arguments.Count -gt 0) { $Plan.Arguments[0] } else { "$env:USERPROFILE\Pictures\IntentShell_Capture_$(Get-Date -Format 'yyyyMMdd_HHmmss').png" }
                    Get-Screenshot -Path $path
                    return [ModuleResult]::new($true, "Screenshot Saved: $path")
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by MediaOperationsModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([MediaOperationsModule]::new())
}

Export-ModuleMember -Function Set-Volume, Set-Brightness, Get-Screenshot
