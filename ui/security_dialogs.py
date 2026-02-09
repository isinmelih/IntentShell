import tkinter as tk
from tkinter import messagebox
import logging
import datetime
import os

def show_ghost_mode_warning(parent=None):
    """
    Displays the 'Legal Shield' warning dialog for Ghost Mode activation.
    Returns True if user successfully completes the challenge, False otherwise.
    """
    
    # Initialize root window logic
    created_root = False
    if parent:
        root = parent
    else:
        root = tk.Tk()
        root.withdraw() # Hide the main window
        created_root = True
    
    # Create a custom TopLevel window
    dialog = tk.Toplevel(root)
    dialog.title("⚠️ Advanced System Mode (Kernel-Level Risk)")
    dialog.geometry("600x570")
    dialog.resizable(False, False)
    dialog.configure(bg="#2b2b2b") # Dark theme
    
    # Force focus
    dialog.grab_set()
    dialog.focus_force()
    
    # Result container
    result = {"authorized": False}
    
    def on_close():
        dialog.destroy()
        if created_root:
            root.destroy()
        
    dialog.protocol("WM_DELETE_WINDOW", on_close)

    # --- UI Elements ---
    
    # Icon/Header
    header_frame = tk.Frame(dialog, bg="#2b2b2b")
    header_frame.pack(pady=20)
    
    lbl_icon = tk.Label(header_frame, text="⚠️", font=("Segoe UI Emoji", 48), bg="#2b2b2b", fg="#ff4444")
    lbl_icon.pack()
    
    lbl_title = tk.Label(header_frame, text="KERNEL ACCESS WARNING", font=("Segoe UI", 16, "bold"), bg="#2b2b2b", fg="#ff4444")
    lbl_title.pack()

    # Warning Text
    warning_text = """
    This mode enables experimental system-level operations intended for 
    ADVANCED USERS and RESEARCH PURPOSES ONLY.

    • Enables direct memory access (GhostDriver)
    • May affect system stability and OS integrity
    • May trigger antivirus/EDR alerts
    
    This mode is NOT required for normal operation or normal usage.

    If you are unsure, close this window.
    
    By continuing, you acknowledge that you understand the risks 
    and take FULL RESPONSIBILITY for any consequences.
    """
    
    lbl_warning = tk.Label(dialog, text=warning_text, font=("Consolas", 10), bg="#2b2b2b", fg="#cccccc", justify="left")
    lbl_warning.pack(pady=10, padx=20)
    
    # Challenge Input
    lbl_challenge = tk.Label(dialog, text="Type 'I UNDERSTAND THE RISK' to continue:", font=("Segoe UI", 10, "bold"), bg="#2b2b2b", fg="white")
    lbl_challenge.pack(pady=(10, 5))
    
    entry_var = tk.StringVar()
    entry_challenge = tk.Entry(dialog, textvariable=entry_var, font=("Consolas", 12), width=30, justify="center")
    entry_challenge.pack(pady=5)
    
    # Button
    btn_enable = tk.Button(dialog, text="ENABLE ADVANCED MODE", font=("Segoe UI", 10, "bold"), 
                           bg="#444444", fg="#aaaaaa", state="disabled", command=lambda: authorize())
    btn_enable.pack(pady=20, ipadx=20, ipady=5)
    
    # --- Logic ---
    
    def check_input(*args):
        if entry_var.get() == "I UNDERSTAND THE RISK":
            btn_enable.config(state="normal", bg="#ff4444", fg="white", cursor="hand2")
        else:
            btn_enable.config(state="disabled", bg="#444444", fg="#aaaaaa", cursor="")
            
    entry_var.trace("w", check_input)
    
    def authorize():
        result["authorized"] = True
        on_close()

    # Center window
    dialog.update_idletasks()
    width = dialog.winfo_width()
    height = dialog.winfo_height()
    x = (dialog.winfo_screenwidth() // 2) - (width // 2)
    y = (dialog.winfo_screenheight() // 2) - (height // 2)
    dialog.geometry(f'{width}x{height}+{x}+{y}')

    # Run loop
    root.wait_window(dialog)
    return result["authorized"]

if __name__ == "__main__":
    # Test
    if show_ghost_mode_warning():
        print("AUTHORIZED")
    else:
        print("DENIED")
