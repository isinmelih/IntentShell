using module .\SystemCore.psm1

# IntentShell Window Operations Module
# Provides capabilities to manage application windows via User32.dll
# Capabilities: Minimize All, Maximize/Restore, Focus App, List Windows

# Compile C# P/Invoke wrapper for User32.dll
$User32Code = @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;

public class WindowManager {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    // ShowWindow Constants
    public const int SW_HIDE = 0;
    public const int SW_SHOWNORMAL = 1;
    public const int SW_SHOWMINIMIZED = 2;
    public const int SW_MAXIMIZE = 3;
    public const int SW_SHOWNOACTIVATE = 4;
    public const int SW_SHOW = 5;
    public const int SW_MINIMIZE = 6;
    public const int SW_SHOWMINNOACTIVE = 7;
    public const int SW_SHOWNA = 8;
    public const int SW_RESTORE = 9;

    public class WindowInfo {
        public IntPtr Handle;
        public string Title;
    }

    public static List<WindowInfo> GetOpenWindows() {
        List<WindowInfo> windows = new List<WindowInfo>();

        EnumWindows(delegate(IntPtr wnd, IntPtr param) {
            int length = GetWindowTextLength(wnd);
            if (length == 0) return true;

            StringBuilder sb = new StringBuilder(length + 1);
            GetWindowText(wnd, sb, sb.Capacity);
            
            string title = sb.ToString();
            if (!string.IsNullOrWhiteSpace(title) && IsWindowVisible(wnd)) {
                 windows.Add(new WindowInfo { Handle = wnd, Title = title });
            }
            return true;
        }, IntPtr.Zero);

        return windows;
    }

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    
    public const uint WM_CLOSE = 0x0010;
}
"@

try {
    Add-Type -TypeDefinition $User32Code -Language CSharp -ErrorAction Stop
} catch {
    Write-Verbose "WindowManager already loaded."
}

function Close-ActiveWindow {
    $hwnd = [WindowManager]::GetForegroundWindow()
    if ($hwnd -ne [IntPtr]::Zero) {
        # Send WM_CLOSE
        [WindowManager]::PostMessage($hwnd, [WindowManager]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
        Write-Output "Sent Close Signal to active window."
    } else {
        Write-Warning "No active window detected."
    }
}

function Get-ActiveWindow {
    $hwnd = [WindowManager]::GetForegroundWindow()
    if ($hwnd -ne [IntPtr]::Zero) {
        $length = [WindowManager]::GetWindowTextLength($hwnd)
        $sb = [System.Text.StringBuilder]::new($length + 1)
        [void][WindowManager]::GetWindowText($hwnd, $sb, $sb.Capacity)
        return @{ Handle = $hwnd; Title = $sb.ToString() }
    }
    return $null
}

function Minimize-All-Windows {
    # PowerShell equivalent of Win+D / Win+M is tricky via API alone without Shell object
    # But we can use Shell.Application
    $shell = New-Object -ComObject Shell.Application
    $shell.MinimizeAll()
    Write-Output "All windows minimized."
}

function Restore-All-Windows {
    $shell = New-Object -ComObject Shell.Application
    $shell.UndoMinimizeAll()
    Write-Output "All windows restored."
}

function Send-KeyboardInput {
    param([string]$Key)

    if ($Key -eq "Ctrl+W") {
        # VK_CONTROL = 0x11, VK_W = 0x57
        # KEYEVENTF_KEYUP = 0x0002
        # KEYEVENTF_EXTENDEDKEY = 0x0001
        
        # 1. Press CTRL
        [WindowManager]::keybd_event(0x11, 0, 0, [UIntPtr]::Zero) 
        Start-Sleep -Milliseconds 100
        
        # 2. Press W
        [WindowManager]::keybd_event(0x57, 0, 0, [UIntPtr]::Zero) 
        Start-Sleep -Milliseconds 100
        
        # 3. Release W
        [WindowManager]::keybd_event(0x57, 0, 2, [UIntPtr]::Zero) 
        Start-Sleep -Milliseconds 50
        
        # 4. Release CTRL
        [WindowManager]::keybd_event(0x11, 0, 2, [UIntPtr]::Zero) 
        
        Write-Output "Sent Ctrl+W (Deep)"
    }
}

function Focus-Window {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProcessName
    )

    try {
        # Filter for processes with a MainWindowTitle
        # Get-Process can return an array, so we filter and select the first one
        $proc = Get-Process $ProcessName -ErrorAction Stop | Where-Object { $_.MainWindowTitle } | Select-Object -First 1

        if ($proc) {
            $handle = $proc.MainWindowHandle
            if ($handle -ne [IntPtr]::Zero) {
                # 1. Try SwitchToThisWindow (Most aggressive)
                [WindowManager]::SwitchToThisWindow($handle, $true)
                
                # 2. Try SetForegroundWindow (Standard)
                [void][WindowManager]::SetForegroundWindow($handle)
                
                # 3. Restore if minimized
                [void][WindowManager]::ShowWindow($handle, 9) # SW_RESTORE

                Write-Output "Focused on '$($proc.MainWindowTitle)'."
            } else {
                 Write-Warning "Process '$ProcessName' has no valid Window Handle."
            }
        } else {
            Write-Warning "No active window found for process '$ProcessName'."
        }
    }
    catch {
        Write-Warning "Failed to focus window: $_"
    }
}

function Minimize-Window {
    param([string]$TitlePattern)
    
    $windows = [WindowManager]::GetOpenWindows()
    $target = $windows | Where-Object { $_.Title -match $TitlePattern } | Select-Object -First 1
    
    if ($target) {
        [WindowManager]::ShowWindow($target.Handle, 6) # SW_MINIMIZE
        Write-Output "Minimized window: $($target.Title)"
    } else {
        Write-Warning "No window found matching '$TitlePattern'"
    }
}

function Get-WindowList {
    [WindowManager]::GetOpenWindows() | Select-Object Handle, Title | Format-Table -AutoSize
}

class WindowOperationsModule {
    [string]$Name
    [hashtable]$Capabilities
    [string[]]$Dependencies
    [string]$Description

    WindowOperationsModule() {
        $this.Name = "WindowOperations"
        $this.Capabilities = @{}
        $this.Dependencies = @()
        
        $this.Capabilities['System'] = 'ReadWrite'
        $this.Description = "Window Management Module"
    }

    [ModuleResult] Run([object]$InputData, [SystemContext]$Context) {
        if ($InputData -is [ExecutionPlan]) {
            $Plan = $InputData
            switch ($Plan.Action) {
                "Window:MinimizeAll" { 
                    Minimize-All-Windows
                    return [ModuleResult]::new($true, "All Windows Minimized")
                }
                "Window:RestoreAll" { 
                    Restore-All-Windows
                    return [ModuleResult]::new($true, "All Windows Restored")
                }
                "Window:Focus" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Window:Focus requires ProcessName argument.") }
                    Focus-Window -ProcessName $Plan.Arguments[0]
                    return [ModuleResult]::new($true, "Window Focus Attempted")
                }
                "Window:SendKeys" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Window:SendKeys requires Key argument.") }
                    Send-KeyboardInput -Key $Plan.Arguments[0]
                    return [ModuleResult]::new($true, "Keyboard Input Sent")
                }
                "Window:Minimize" {
                    if ($Plan.Arguments.Count -lt 1) { return [ModuleResult]::new($false, "Window:Minimize requires TitlePattern argument.") }
                    Minimize-Window -TitlePattern $Plan.Arguments[0]
                    return [ModuleResult]::new($true, "Window Minimize Attempted")
                }
                "Window:List" { 
                    $list = Get-WindowList
                    $mr = [ModuleResult]::new($true, "Window List Retrieved")
                    $mr.Data = $list
                    return $mr
                }
                "Window:CloseActive" {
                    Close-ActiveWindow
                    return [ModuleResult]::new($true, "Active Window Closed")
                }
                default {
                    return [ModuleResult]::new($false, "Action '$($Plan.Action)' is not supported by WindowOperationsModule.")
                }
            }
        }
        return [ModuleResult]::new($false, "Invalid Input: Expected ExecutionPlan")
    }
}

if ([System.Management.Automation.PSTypeName]::new("SystemCore").Type -ne $null) {
    [SystemCore]::RegisterModule([WindowOperationsModule]::new())
}

Export-ModuleMember -Function Minimize-All-Windows, Restore-All-Windows, Focus-Window, Minimize-Window, Get-WindowList, Send-KeyboardInput, Close-ActiveWindow, Get-ActiveWindow
