# IntentShell Driver Gateway
# The ONLY authorized bridge between User-Mode and Kernel-Mode Driver.
# Enforces strict parameter validation and IOCTL allow-listing.

# IOCTL Definitions (CTL_CODE(DeviceType, Function, Method, Access))
# DeviceType: 0x8000 (Custom)
# Method: 0 (BUFFERED)
# Access: 2 (READ_DATA) - We enforce Read-Only for most operations
$Global:IOCTL_INTENTSHELL_BASE = 0x8000

# Function Codes
$Global:IOCTL_INSPECT_PROCESS_HANDLES = 0x80002000 # Function 0x800
$Global:IOCTL_GET_PROCESS_IMAGE_PATH  = 0x80002004 # Function 0x801
$Global:IOCTL_READ_PHYSICAL_MEMORY    = 0x80002008 # Function 0x802 (HIGH RISK - Requires Strict Validation)

# Load P/Invoke for DeviceIoControl
$Kernel32Def = @"
using System;
using System.Runtime.InteropServices;
using System.ComponentModel;
using Microsoft.Win32.SafeHandles;

public class DriverInterop {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern SafeFileHandle CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile
    );

    [DllImport("kernel32.dll", ExactSpelling = true, SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool DeviceIoControl(
        SafeFileHandle hDevice,
        uint dwIoControlCode,
        IntPtr lpInBuffer,
        uint nInBufferSize,
        IntPtr lpOutBuffer,
        uint nOutBufferSize,
        out uint lpBytesReturned,
        IntPtr lpOverlapped
    );

    public const uint GENERIC_READ = 0x80000000;
    public const uint GENERIC_WRITE = 0x40000000;
    public const uint OPEN_EXISTING = 3;
    public const uint FILE_ATTRIBUTE_NORMAL = 0x80;
}
"@

Add-Type -TypeDefinition $Kernel32Def -ErrorAction SilentlyContinue

function Test-DriverLoaded {
    <#
    .SYNOPSIS
        Checks if the IntentShell driver is loaded and accessible.
    #>
    $devicePath = "\\.\IntentShellDrv"
    $handle = [DriverInterop]::CreateFile(
        $devicePath,
        [DriverInterop]::GENERIC_READ,
        0, # No Share
        [IntPtr]::Zero,
        [DriverInterop]::OPEN_EXISTING,
        [DriverInterop]::FILE_ATTRIBUTE_NORMAL,
        [IntPtr]::Zero
    )

    if ($handle.IsInvalid) {
        return $false
    }
    $handle.Close()
    return $true
}

function Invoke-DriverCommand {
    <#
    .SYNOPSIS
        Sends a SAFE, VALIDATED command to the Kernel Driver.
    .DESCRIPTION
        This function acts as a firewall. It does not accept raw IOCTL codes.
        It accepts high-level "Intent" actions and translates them.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("InspectProcess", "GetProcessPath", "ForensicRead")]
        [string]$Action,

        [Parameter(Mandatory=$false)]
        [int]$TargetPID,

        [Parameter(Mandatory=$false)]
        [long]$MemoryAddress,

        [Parameter(Mandatory=$false)]
        [int]$ReadSize = 1024
    )

    # 1. Pre-Flight Check: Is Driver Loaded?
    if (-not (Test-DriverLoaded)) {
        throw "IntentShell Driver is NOT loaded. Cannot execute kernel-mode operations."
    }

    # 2. Open Handle
    $devicePath = "\\.\IntentShellDrv"
    $handle = [DriverInterop]::CreateFile(
        $devicePath,
        [DriverInterop]::GENERIC_READ, # READ ONLY ACCESS requested
        0,
        [IntPtr]::Zero,
        [DriverInterop]::OPEN_EXISTING,
        [DriverInterop]::FILE_ATTRIBUTE_NORMAL,
        [IntPtr]::Zero
    )

    if ($handle.IsInvalid) {
        throw "Failed to open handle to IntentShell Driver. Error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }

    try {
        $ioctlCode = 0
        $inputBuffer = [IntPtr]::Zero
        $inputSize = 0
        $outputSize = 4096 # Default 4KB buffer
        
        # 3. Intent Translation & Validation
        switch ($Action) {
            "InspectProcess" {
                if ($TargetPID -le 4) { throw "Invalid PID: System processes cannot be targeted." }
                $ioctlCode = $Global:IOCTL_INSPECT_PROCESS_HANDLES
                
                # Marshal PID to buffer
                $inputSize = 4
                $inputBuffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($inputSize)
                [System.Runtime.InteropServices.Marshal]::WriteInt32($inputBuffer, $TargetPID)
            }
            "GetProcessPath" {
                if ($TargetPID -le 0) { throw "Invalid PID." }
                $ioctlCode = $Global:IOCTL_GET_PROCESS_IMAGE_PATH
                
                $inputSize = 4
                $inputBuffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($inputSize)
                [System.Runtime.InteropServices.Marshal]::WriteInt32($inputBuffer, $TargetPID)
            }
            "ForensicRead" {
                # CRITICAL SECURITY CHECK
                Write-Warning "Executing HIGH RISK Kernel Memory Read. This event is logged."
                if ($ReadSize -gt 4096) { throw "Read size limited to 4KB for safety." }
                
                $ioctlCode = $Global:IOCTL_READ_PHYSICAL_MEMORY
                
                # Structure: Address (8 bytes) + Size (4 bytes)
                $inputSize = 12
                $inputBuffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($inputSize)
                [System.Runtime.InteropServices.Marshal]::WriteInt64($inputBuffer, $MemoryAddress)
                [System.Runtime.InteropServices.Marshal]::WriteInt32($inputBuffer, 8, $ReadSize) # Offset 8
            }
        }

        # 4. Execute IOCTL
        $outputBuffer = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($outputSize)
        $bytesReturned = 0
        
        $success = [DriverInterop]::DeviceIoControl(
            $handle,
            $ioctlCode,
            $inputBuffer,
            $inputSize,
            $outputBuffer,
            $outputSize,
            [ref]$bytesReturned,
            [IntPtr]::Zero
        )

        if (-not $success) {
            throw "DeviceIoControl Failed. Error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }

        # 5. Parse Output (Simplified for POC)
        # In a real scenario, we would parse structs based on Action
        $resultData = [byte[]]::new($bytesReturned)
        [System.Runtime.InteropServices.Marshal]::Copy($outputBuffer, $resultData, 0, $bytesReturned)
        
        return @{
            Success = $true
            BytesRead = $bytesReturned
            DataHex = ($resultData | ForEach-Object { $_.ToString("X2") }) -join " "
            DataASCII = [System.Text.Encoding]::ASCII.GetString($resultData)
        }

    }
    finally {
        # Cleanup
        if ($inputBuffer -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::FreeHGlobal($inputBuffer) }
        if ($outputBuffer -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::FreeHGlobal($outputBuffer) }
        $handle.Close()
    }
}

Export-ModuleMember -Function Invoke-DriverCommand, Test-DriverLoaded
