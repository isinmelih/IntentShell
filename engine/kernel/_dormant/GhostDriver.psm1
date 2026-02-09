# IntentShell Ghost Driver (Runtime C# Kernel Proxy)
# Provides "Driver-Like" capabilities via Unsafe C# P/Invoke.
# No WDK required. Compiles in-memory.

if (-not $Global:IntentShellConfig.ExperimentalModeEnabled) {
    throw "Access Denied: Experimental Kernel Mode required. Run 'intentshell experimental join' to enable."
}

$GhostDriverCode = @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Diagnostics;

public class GhostCore {
    
    // PROCESS_ALL_ACCESS = 0x1F0FFF
    // PROCESS_VM_READ = 0x0010
    // PROCESS_QUERY_INFORMATION = 0x0400
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(
        uint dwDesiredAccess,
        bool bInheritHandle,
        int dwProcessId
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool ReadProcessMemory(
        IntPtr hProcess,
        IntPtr lpBaseAddress,
        [Out] byte[] lpBuffer,
        int dwSize,
        out IntPtr lpNumberOfBytesRead
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("psapi.dll", SetLastError = true)]
    public static extern uint GetModuleFileNameEx(
        IntPtr hProcess,
        IntPtr hModule,
        [Out] StringBuilder lpBaseName,
        [In] [MarshalAs(UnmanagedType.U4)] int nSize
    );

    // DANGER ZONE: This method mimics a driver reading memory
    public static string InspectProcessMemory(int pid, long address, int size) {
        IntPtr hProcess = IntPtr.Zero;
        try {
            // Requesting VM_READ (0x0010) + QUERY_INFO (0x0400)
            hProcess = OpenProcess(0x0410, false, pid);
            
            if (hProcess == IntPtr.Zero) {
                return "ACCESS_DENIED (Error: " + Marshal.GetLastWin32Error() + ")";
            }

            byte[] buffer = new byte[size];
            IntPtr bytesRead;
            
            bool success = ReadProcessMemory(hProcess, (IntPtr)address, buffer, size, out bytesRead);
            
            if (!success) {
                 return "READ_FAILED (Error: " + Marshal.GetLastWin32Error() + ")";
            }

            // Convert to Hex String for display
            return BitConverter.ToString(buffer, 0, (int)bytesRead).Replace("-", " ");
        }
        catch (Exception ex) {
            return "EXCEPTION: " + ex.Message;
        }
        finally {
            if (hProcess != IntPtr.Zero) CloseHandle(hProcess);
        }
    }

    public static string GetRealProcessPath(int pid) {
         IntPtr hProcess = IntPtr.Zero;
         try {
            hProcess = OpenProcess(0x0410, false, pid); // Query Info + Read
            if (hProcess == IntPtr.Zero) return "Unknown";

            StringBuilder sb = new StringBuilder(1024);
            GetModuleFileNameEx(hProcess, IntPtr.Zero, sb, sb.Capacity);
            return sb.ToString();
         }
         finally {
            if (hProcess != IntPtr.Zero) CloseHandle(hProcess);
         }
    }
}
"@

# Compile the C# code into memory
try {
    Add-Type -TypeDefinition $GhostDriverCode -Language CSharp -ErrorAction Stop
}
catch {
    Write-Warning "GhostDriver is already loaded or failed to compile."
}

function Invoke-GhostRead {
    <#
    .SYNOPSIS
        Reads memory from another process using the Ghost Driver.
    #>
    param(
        [int]$Pid,
        [long]$Address, # 0 for base address (simplified)
        [int]$Size = 32
    )

    # If Address is 0, try to read the PE Header (usually at base address)
    # Note: Finding base address from PowerShell is tricky without more P/Invoke,
    # so we will trust the user or just attempt a common offset if they provide one.
    
    # In a real scenario, we would use Process.MainModule.BaseAddress
    if ($Address -eq 0) {
        try {
            $proc = Get-Process -Id $Pid -ErrorAction Stop
            $Address = $proc.MainModule.BaseAddress.ToInt64()
            Write-Host "Auto-detected Base Address: 0x$($Address.ToString('X'))" -ForegroundColor Gray
        }
        catch {
            Write-Warning "Could not determine base address. Access might be denied."
        }
    }

    return [GhostCore]::InspectProcessMemory($Pid, $Address, $Size)
}

function Get-GhostPath {
    param([int]$Pid)
    return [GhostCore]::GetRealProcessPath($Pid)
}

Export-ModuleMember -Function Invoke-GhostRead, Get-GhostPath
