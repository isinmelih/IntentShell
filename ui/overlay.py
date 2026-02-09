import tkinter as tk
from tkinter import ttk, font
import threading
import keyboard
import sys
import os
import getpass
import datetime
import random

# Ensure path is correct
sys.path.append(os.getcwd())

from core.bridge_runner import RunnerBridge
from core.schemas import RiskLevel
from core.user_profile import UserProfile
from core.powershell_session import PowerShellSession
from core.execution import ExecutionManager
from core.command_explainer import CommandExplainer

class IntentShellOverlay:
    def __init__(self, root):
        self.root = root
        self.root.title("IntentShell")
        
        # Window Setup: Frameless, Topmost, Center
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.attributes("-alpha", 0.95)
        
        # Colors & Fonts
        self.bg_color = "#1e1e1e"
        self.fg_color = "#ffffff"
        self.accent_color = "#007acc"
        self.error_color = "#f48771"
        self.warning_color = "#cca700"
        self.success_color = "#89d185"
        
        self.font_entry = font.Font(family="Consolas", size=14)
        self.font_log = font.Font(family="Consolas", size=10)
        
        self.root.configure(bg=self.bg_color)
        
        # Layout Dimensions
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        width = 700
        height = 80 # Initial height (just input)
        x = (screen_width - width) // 2
        y = (screen_height - height) // 3 # Slightly above center
        
        self.geometry_base = f"{width}x{height}+{x}+{y}"
        self.root.geometry(self.geometry_base)
        
        # UI Elements
        self.main_frame = tk.Frame(root, bg=self.bg_color, highlightthickness=1, highlightbackground=self.accent_color)
        self.main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Input Field
        self.input_var = tk.StringVar()
        self.entry = tk.Entry(
            self.main_frame, 
            textvariable=self.input_var, 
            font=self.font_entry,
            bg="#252526", 
            fg=self.fg_color,
            insertbackground="white",
            relief=tk.FLAT,
            bd=5
        )
        self.entry.pack(fill=tk.X, padx=10, pady=10)
        self.entry.bind("<Return>", self.process_intent)
        self.entry.bind("<Escape>", self.hide_window)
        self.entry.focus_set()
        
        # Hint Label
        self.hint_label = tk.Label(
            self.main_frame,
            text="Press Esc to close",
            bg=self.bg_color,
            fg="#666666",
            font=("Consolas", 8)
        )
        self.hint_label.pack(side=tk.BOTTOM, pady=(0, 5))
        
        # Status/Log Area (Hidden initially)
        self.log_text = tk.Text(
            self.main_frame,
            height=10,
            bg="#1e1e1e",
            fg="#cccccc",
            font=self.font_log,
            relief=tk.FLAT,
            state=tk.NORMAL,
            wrap=tk.WORD
        )
        self.log_text.bind("<Key>", self.prevent_modification)
        
        # Context Menu
        self.context_menu = tk.Menu(self.log_text, tearoff=0, bg="#2d2d2d", fg="white")
        self.context_menu.add_command(label="Copy", command=self.copy_selection)
        self.context_menu.add_command(label="Clear", command=self.clear_log)
        self.log_text.bind("<Button-3>", self.show_context_menu)
        
        # Developer Mode UI Elements (Hidden by default)
        self.dev_frame = tk.Frame(self.main_frame, bg="#2d2d2d", height=30)
        self.dev_label = tk.Label(self.dev_frame, text="DEV MODE", bg="#2d2d2d", fg="#ffcc00", font=("Consolas", 8, "bold"))
        self.dev_label.pack(side=tk.LEFT, padx=5)
        
        self.btn_export = tk.Button(self.dev_frame, text="Export Report", command=self.export_report, bg="#3e3e3e", fg="white", font=("Consolas", 8), relief=tk.FLAT)
        self.btn_export.pack(side=tk.RIGHT, padx=5, pady=2)
        
        # Initialize Components
        self.session = PowerShellSession()
        self.exec_manager = ExecutionManager(self.session)
        self.explainer = CommandExplainer()
        self.executor = RunnerBridge(self.log_output, session=self.session)
        self.profile = UserProfile()
        
        # Check Developer Mode
        self.dev_mode_enabled = self.check_dev_mode()
        if self.dev_mode_enabled:
            self.dev_frame.pack(side=tk.TOP, fill=tk.X)
            self.root.geometry(f"{width}x{height + 30}+{x}+{y}") # Adjust initial height
        
        # State
        self.current_intent = None
        self.current_command = None
        self.current_user_input = None
        self.waiting_confirmation = False
        self.confirmation_code = None
        self.current_risk_assessment = None
        self.trust_mod = 0.0
        self.effective_risk_level = None
        self.experimental_join_stage = 0 # 0=None, 1=Math, 2=Agreement, 3=Username
        self.math_challenge_answer = None
        
        # Thinking Animation
        self.thinking_active = False
        self.thinking_dots = 0
        self.thinking_timer = None
        
    def check_dev_mode(self):
        try:
            config_path = os.path.join("config", "main.ini")
            import configparser
            config = configparser.ConfigParser()
            if os.path.exists(config_path):
                config.read(config_path, encoding='utf-8')
                if config.has_option("Developer", "enabled"):
                    return config.getboolean("Developer", "enabled")
            return False
        except:
            return False

    def export_report(self):
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        report_file = f"dev_report_{timestamp}.log"
        try:
            with open(report_file, "w", encoding="utf-8") as f:
                f.write("=== IntentShell Developer Diagnostic Report ===\n")
                f.write(f"Generated: {datetime.datetime.now()}\n")
                f.write(f"User: {getpass.getuser()}\n")
                f.write(f"Session Active: {bool(self.session.process)}\n")
                f.write("-" * 40 + "\n")
                f.write("Recent Logs:\n")
                f.write(self.log_text.get("1.0", tk.END))
            
            self.log_output(f"Report exported: {report_file}", "success")
            # Open the file location
            os.system(f"explorer /select,{os.path.abspath(report_file)}")
        except Exception as e:
            self.log_output(f"Export failed: {e}", "error")

    def show_window(self):
        self.root.deiconify()
        self.entry.focus_set()
        self.entry.selection_range(0, tk.END)
        
    def hide_window(self, event=None):
        self.root.withdraw()
        self.reset_ui()
        
    def reset_ui(self):
        self.stop_thinking_animation()
        self.input_var.set("")
        self.log_text.pack_forget()
        self.root.geometry(self.geometry_base)
        self.clear_log()
        self.waiting_confirmation = False
        self.confirmation_code = None
        self.current_intent = None
        self.current_command = None
        self.current_user_input = None
        self.current_risk_assessment = None
        self.trust_mod = 0.0
        self.effective_risk_level = None
        self.experimental_join_stage = 0
        self.main_frame.configure(highlightbackground=self.accent_color)
        
    def expand_window(self):
        # Increase height to show logs
        current_geom = self.root.geometry()
        width = 700
        height = 400
        x = self.root.winfo_x()
        y = self.root.winfo_y()
        self.root.geometry(f"{width}x{height}+{x}+{y}")
        self.log_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))
        
    def log_output(self, text: str, style: str = "info"):
        def _update():
            # self.log_text.configure(state=tk.NORMAL) # Always NORMAL now
            
            tag = "normal"
            if style == "error":
                tag = "error"
                self.log_text.tag_config("error", foreground=self.error_color)
            elif style == "warning":
                tag = "warning"
                self.log_text.tag_config("warning", foreground=self.warning_color)
            elif style == "success":
                tag = "success"
                self.log_text.tag_config("success", foreground=self.success_color)
            elif style == "critical":
                tag = "critical"
                self.log_text.tag_config("critical", foreground="#ff0000", font=("Consolas", 10, "bold"))
                
            self.log_text.insert(tk.END, text + "\n", tag)
            self.log_text.see(tk.END)
            # self.log_text.configure(state=tk.DISABLED)
        
        self.root.after(0, _update)

    def start_thinking_animation(self):
        if self.thinking_active:
            return
            
        self.thinking_active = True
        self.thinking_dots = 0
        
        # Initial Message
        self.log_output("Thinking", "info")
        
        def _animate():
            if not self.thinking_active:
                return
                
            self.thinking_dots = (self.thinking_dots + 1) % 4
            dots_str = "." * self.thinking_dots
            
            # Update the last line (Thinking...)
            def _update_ui():
                try:
                    # Delete last line content if it starts with Thinking
                    last_line_idx = self.log_text.index("end-2l linestart")
                    last_line_text = self.log_text.get(last_line_idx, "end-2l lineend")
                    
                    if "Thinking" in last_line_text:
                        self.log_text.delete(last_line_idx, "end-2l lineend")
                        self.log_text.insert(last_line_idx, f"Thinking{dots_str}")
                except:
                    pass
            
            self.root.after(0, _update_ui)
            
            # Schedule next frame
            self.thinking_timer = self.root.after(500, _animate)
            
        _animate()

    def stop_thinking_animation(self):
        self.thinking_active = False
        if self.thinking_timer:
            self.root.after_cancel(self.thinking_timer)
            self.thinking_timer = None
            
        # Clear "Thinking..." line
        def _clear_thinking():
            try:
                last_line_idx = self.log_text.index("end-2l linestart")
                last_line_text = self.log_text.get(last_line_idx, "end-2l lineend")
                if "Thinking" in last_line_text:
                     self.log_text.delete(last_line_idx, "end-1c") # Remove line
            except:
                pass
        self.root.after(0, _clear_thinking)

    def clear_log(self):
        def _clear():
            # self.log_text.configure(state=tk.NORMAL)
            self.log_text.delete(1.0, tk.END)
            # self.log_text.configure(state=tk.DISABLED)
        self.root.after(0, _clear)

    def prevent_modification(self, event):
        # Allow navigation and copy
        if event.keysym in ["Left", "Right", "Up", "Down", "Home", "End", "Prior", "Next"]:
            return None
        if (event.state & 4) and event.keysym.lower() == 'c': # Ctrl+C
            self.copy_selection()
            return "break"
        if (event.state & 4) and event.keysym.lower() == 'a': # Ctrl+A
            self.select_all()
            return "break"
        return "break"

    def show_context_menu(self, event):
        try:
            self.context_menu.tk_popup(event.x_root, event.y_root)
        finally:
            self.context_menu.grab_release()

    def copy_selection(self, event=None):
        try:
            sel = self.log_text.get(tk.SEL_FIRST, tk.SEL_LAST)
            self.root.clipboard_clear()
            self.root.clipboard_append(sel)
        except tk.TclError:
            pass # No selection

    def select_all(self, event=None):
        self.log_text.tag_add(tk.SEL, "1.0", tk.END)
        self.log_text.mark_set(tk.INSERT, "1.0")
        self.log_text.see(tk.INSERT)
        return "break"

    def process_intent(self, event=None):
        user_input = self.input_var.get().strip()
        
        if self.experimental_join_stage > 0:
            self.handle_experimental_flow(user_input)
            return

        if self.waiting_confirmation:
            self.handle_confirmation(user_input)
            return

        # If not waiting for confirmation, we need actual input
        if not user_input:
            return

        # Start Processing in Thread
        self.expand_window()
        self.clear_log()
        self.start_thinking_animation()
        # self.root.update() # No longer needed as we are in thread, but safe to remove
        
        threading.Thread(target=self._process_async, args=(user_input,), daemon=True).start()

    def _process_async(self, user_input):
        self.current_user_input = user_input
        # 1. Unified Processing (Normalize -> Parse -> Dispatch -> Assess)
        try:
            # Uses the Single Entry Point Logic
            self.current_intent, self.current_command, self.current_risk_assessment = \
                self.exec_manager.process_input(user_input, bypass_cache=False)
            
            self.stop_thinking_animation()

            if self.current_intent.intent_type == "unknown":
                self.log_output("Could not understand intent.", "error")
                return
            # Security Challenge Check
            if self.current_intent.intent_type == "security_challenge_required":
                self.log_output(f"🔒 {self.current_intent.description}", "warning")
                self.log_output("Launching Security Dialog...", "warning")
                
                # Run UI on main thread and wait for result
                auth_event = threading.Event()
                auth_result = {"success": False}
                
                def run_dialog():
                    # This runs on main thread
                    success = self.session.enable_ghost_mode(parent_window=self.root)
                    auth_result["success"] = success
                    auth_event.set()
                    
                self.root.after(0, run_dialog)
                auth_event.wait() # Block this thread until dialog closes
                
                if auth_result["success"]:
                     self.log_output("✅ Security Challenge Passed. Ghost Mode Enabled.", "success")
                     self.log_output("Retrying original intent...", "dim")
                     # Retry resolution with new permissions
                     self.current_intent, self.current_command, self.current_risk_assessment = \
                        self.exec_manager.process_input(user_input, bypass_cache=True) # Bypass cache on retry
                else:
                     self.log_output("❌ Authorization Denied. Operation blocked.", "error")
                     return

            # Experimental Mode Join Flow
            if self.current_intent.intent_type == "experimental_join":
                 self.root.after(0, self.initiate_experimental_join_flow)
                 return
                
            # 2. Explain
            # Pass risk assessment to explainer for "Honesty Mode"
            explanation = self.explainer.explain(self.current_intent, self.current_risk_assessment)
            self.log_output(explanation, "info")
            
            # 3. Command is already generated by ExecutionManager
            self.log_output(f"Cmd: {self.current_command}", "dim")
            
            # 3.5. Time-based Risk Decay
            # We trigger a decay check here to simulate time passage or just periodic cleanup
            self.exec_manager.sentinel.suspension_system.record_risk(RiskLevel.LOW, "", "", [])

            # 4. Dry Run
            self.executor.dry_run(self.current_command, self.current_intent.description)
            
            # 5. Risk Assessment is already done by ExecutionManager
            # self.current_risk_assessment = ...
            
            # 6. Apply Trust Modifier
            # If user has done this many times, we might skip HIGH risk checks if not critical
            self.trust_mod = self.profile.get_trust_modifier(self.current_intent.intent_type)
            if self.trust_mod > 0:
                self.log_output(f"Trust Bonus: {int(self.trust_mod*100)}% (Familiar Action)", "success")
            
            # 7. Ask Confirmation
            self.root.after(0, self.request_confirmation)
            
        except Exception as e:
            self.stop_thinking_animation()
            self.log_output(f"Error: {e}", "error")

    def initiate_experimental_join_flow(self):
        from core.security.kernel_guard import assert_kernel_disabled
        assert_kernel_disabled()

    def handle_experimental_flow(self, user_input):
        from core.security.kernel_guard import assert_kernel_disabled
        assert_kernel_disabled()

    def request_confirmation(self):
        risk_level = self.current_risk_assessment.level
        reasons = self.current_risk_assessment.reasons
        
        # Calculate Effective Risk Level based on Trust
        self.effective_risk_level = risk_level
        
        if self.trust_mod >= 0.3: # High Trust
            if risk_level == RiskLevel.MEDIUM:
                self.effective_risk_level = RiskLevel.LOW
                self.log_output("Risk downgraded due to High Trust", "success")
            elif risk_level == RiskLevel.HIGH:
                self.effective_risk_level = RiskLevel.MEDIUM
                self.log_output("Risk downgraded due to High Trust", "success")
        
        self.log_output("-" * 30)
        # Display original risk, but treat as effective risk
        self.log_output(f"RISK LEVEL: {risk_level.upper()}", "warning" if risk_level != RiskLevel.LOW else "success")
        
        if reasons:
            self.log_output("Reasons:", "warning")
            for reason in reasons:
                self.log_output(f" - {reason}", "warning")
        
        self.waiting_confirmation = True
        self.entry.delete(0, tk.END) # Clear input
        
        if self.effective_risk_level == RiskLevel.HIGH:
            self.main_frame.configure(highlightbackground=self.error_color)
            # High Risk: Require random code
            self.confirmation_code = str(random.randint(1000, 9999))
            self.log_output(f"CRITICAL ACTION. To confirm, type this code: {self.confirmation_code}", "critical")
            
        elif self.effective_risk_level == RiskLevel.MEDIUM:
            self.main_frame.configure(highlightbackground=self.warning_color)
            # Medium Risk: Type YES
            self.confirmation_code = "YES"
            self.log_output("Type 'YES' to confirm", "warning")
            
        else: # LOW (or Downgraded to LOW)
            self.main_frame.configure(highlightbackground=self.success_color)
            # Low Risk: Just Enter or y
            self.confirmation_code = None
            self.log_output("Press ENTER or type 'y' to confirm", "success")

    def handle_confirmation(self, user_input):
        # Use effective_risk_level for validation
        risk_level = self.effective_risk_level
        confirmed = False
        
        if risk_level == RiskLevel.HIGH:
            if user_input == self.confirmation_code:
                confirmed = True
            else:
                self.log_output("Incorrect code. Cancelled.", "error")
                
        elif risk_level == RiskLevel.MEDIUM:
            if user_input.upper() == "YES":
                confirmed = True
            else:
                self.log_output("Cancelled (Type YES to confirm).", "warning")
                
        else: # LOW
            # Allow empty string (ENTER) or explicit yes
            if not user_input or user_input.lower() in ["y", "yes", "evet", ""] or user_input == self.confirmation_code:
                confirmed = True
            else:
                self.log_output(f"Cancelled. Input was: '{user_input}'", "info")
        
        if confirmed:
            self.execute_real_command()
        else:
            self.root.after(1500, self.hide_window)

    def execute_real_command(self):
        self.waiting_confirmation = False
        self.confirmation_code = None
        self.log_output("Executing...", "info")
        # self.root.update() # Removed to prevent blocking, moved to async
        
        # Disable input to prevent race conditions during execution
        self.entry.config(state=tk.DISABLED)
        
        # Run in a separate thread to prevent UI freezing
        threading.Thread(target=self._execute_async, daemon=True).start()

    def _execute_async(self):
        try:
            success = self.executor.execute(self.current_command, self.current_intent)
        except Exception as e:
            self.log_output(f"Execution Error: {e}", "error")
            success = False
            
        # Callback to Main Thread
        self.root.after(0, lambda: self._post_execution(success))

    def _post_execution(self, success):
        # Re-enable input
        self.entry.config(state=tk.NORMAL)
        self.entry.focus_set()
        
        if success:
            self.log_output("Done!", "success")
            # Record success in profile
            if self.current_intent and self.current_risk_assessment:
                self.profile.record_success(self.current_intent.intent_type, self.current_risk_assessment.level.value, self.current_user_input)
                
                # CACHE THE SUCCESSFUL INTENT HERE
                # Using NLUBridge via ExecutionManager
                self.exec_manager.nlu.cache_successful_execution(self.current_user_input, self.current_intent.__dict__)
            
            # Keep window open for next command
            self.input_var.set("") # Clear confirmation text
            self.main_frame.configure(highlightbackground=self.accent_color) # Reset border
            self.log_output("\nReady for next command...", "dim")
        else:
            self.log_output("Failed!", "error")

def main():
    root = tk.Tk()
    app = IntentShellOverlay(root)
    
    # Hide initially
    root.withdraw()
    
    # Load Hotkey from Config
    hotkey = 'alt+k' # Default
    try:
        config_path = os.path.join("config", "main.ini")
        import configparser
        config = configparser.ConfigParser()
        if os.path.exists(config_path):
            config.read(config_path, encoding='utf-8')
            if config.has_option("Hotkey", "hotkey"):
                hotkey = config.get("Hotkey", "hotkey")
    except Exception as e:
        print(f"Error loading hotkey config: {e}")

    # Global Hotkey Setup
    def on_hotkey():
        # Use root.after to run in main thread
        root.after(0, app.show_window)
        
    try:
        keyboard.add_hotkey(hotkey, on_hotkey)
        print(f"IntentShell running... Press {hotkey} to toggle.")
    except Exception as e:
        print(f"Hotkey Error: {e}")
        # Fallback: Just show window if hotkey fails (dev mode)
        app.show_window()
        
    root.mainloop()

if __name__ == "__main__":
    main()
