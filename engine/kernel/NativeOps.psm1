# IntentShell Native Operations (User-Mode)
# Advanced System Internals without Kernel Drivers.
# Uses P/Invoke to access NTAPI (ntdll.dll).

$NativeDef = @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class NativeUtils {
    
    [DllImport("ntdll.dll")]
    public static extern int NtQuerySystemInformation(
        int SystemInformationClass,
        IntPtr SystemInformation,
        int SystemInformationLength,
        out int ReturnLength
    );

    // SystemProcessInformation = 5
    // SystemHandleInformation = 16
    
    public struct SYSTEM_PROCESS_INFORMATION {
        public uint NextEntryOffset;
        public uint NumberOfThreads;
        public long WorkingSetPrivateSize; // Valid for Vista+
        public uint HardFaultCount;
        public uint NumberOfThreadsHighWatermark;
        public ulong CycleTime;
        public long CreateTime;
        public long UserTime;
        public long KernelTime;
        public UNICODE_STRING ImageName;
        public int BasePriority;
        public IntPtr UniqueProcessId;
        public IntPtr InheritedFromUniqueProcessId;
        public uint HandleCount;
        public uint SessionId;
        public UIntPtr PageDirectoryBase;
        public UIntPtr PeakVirtualSize;
        public UIntPtr VirtualSize;
        public uint PageFaultCount;
        public UIntPtr PeakWorkingSetSize;
        public UIntPtr WorkingSetSize;
        public UIntPtr QuotaPeakPagedPoolUsage;
        public UIntPtr QuotaPagedPoolUsage;
        public UIntPtr QuotaPeakNonPagedPoolUsage;
        public UIntPtr QuotaNonPagedPoolUsage;
        public UIntPtr PagefileUsage;
        public UIntPtr PeakPagefileUsage;
        public UIntPtr PrivatePageCount;
        public long ReadOperationCount;
        public long WriteOperationCount;
        public long OtherOperationCount;
        public long ReadTransferCount;
        public long WriteTransferCount;
        public long OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct UNICODE_STRING {
        public ushort Length;
        public ushort MaximumLength;
        public IntPtr Buffer;
    }

    public static List<Dictionary<string, object>> GetNativeProcesses() {
        var results = new List<Dictionary<string, object>>();
        int STATUS_INFO_LENGTH_MISMATCH = -1073741820; // 0xC0000004
        int SystemProcessInformation = 5;
        
        int bufferSize = 128 * 1024;
        IntPtr buffer = Marshal.AllocHGlobal(bufferSize);
        int requiredSize = 0;

        try {
            int status = NtQuerySystemInformation(SystemProcessInformation, buffer, bufferSize, out requiredSize);
            
            while (status == STATUS_INFO_LENGTH_MISMATCH) {
                Marshal.FreeHGlobal(buffer);
                bufferSize = requiredSize + (10 * 1024); // Add slack
                buffer = Marshal.AllocHGlobal(bufferSize);
                status = NtQuerySystemInformation(SystemProcessInformation, buffer, bufferSize, out requiredSize);
            }

            if (status != 0) {
                throw new Exception("NtQuerySystemInformation failed with status: " + status);
            }

            long offset = 0;
            IntPtr currentPtr = buffer;

            while (true) {
                var info = (SYSTEM_PROCESS_INFORMATION)Marshal.PtrToStructure(currentPtr, typeof(SYSTEM_PROCESS_INFORMATION));
                
                string processName = "Idle";
                if (info.ImageName.Buffer != IntPtr.Zero) {
                    processName = Marshal.PtrToStringUni(info.ImageName.Buffer, info.ImageName.Length / 2);
                }

                var dict = new Dictionary<string, object>();
                dict["PID"] = info.UniqueProcessId.ToInt32();
                dict["Name"] = processName;
                dict["Threads"] = info.NumberOfThreads;
                dict["Handles"] = info.HandleCount;
                dict["SessionId"] = info.SessionId;
                dict["KernelTime"] = info.KernelTime;
                dict["UserTime"] = info.UserTime;
                
                results.Add(dict);

                if (info.NextEntryOffset == 0) break;
                offset += info.NextEntryOffset;
                currentPtr = new IntPtr(buffer.ToInt64() + offset);
            }
        }
        finally {
            Marshal.FreeHGlobal(buffer);
        }
        
        return results;
    }
}
"@

Add-Type -TypeDefinition $NativeDef -ErrorAction SilentlyContinue

function Get-NativeProcessList {
    <#
    .SYNOPSIS
        Lists processes using native NTAPI calls (No Drivers needed).
    .DESCRIPTION
        Demonstrates that we can get deep system info (like precise KernelTime)
        without a kernel driver.
    #>
    return [NativeUtils]::GetNativeProcesses()
}

Export-ModuleMember -Function Get-NativeProcessList
