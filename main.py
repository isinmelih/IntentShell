import sys
import os

# Add project root to sys.path
sys.path.append(os.getcwd())

from rich.console import Console
from rich.prompt import Prompt, Confirm
from core.bridge_nlu import NLUBridge
from core.bridge_dispatch import DispatchBridge
from core.command_explainer import CommandExplainer
from core.bridge_runner import RunnerBridge
from core.schemas import RiskLevel
from core.bridge_sentinel import SentinelBridge
from core.powershell_session import PowerShellSession
import getpass
import datetime
import random

console = Console()

def main():
    console.print("[bold blue]IntentShell v1.0.0 (Stable)[/bold blue] - Safe Natural Language Shell", justify="center")
    console.print("[dim]Type 'exit' to quit[/dim]\n")

    # Initialize Persistent Session
    with console.status("[bold green]Initializing Kernel...[/bold green]"):
        session = PowerShellSession()

    parser = NLUBridge(session)
    generator = DispatchBridge(session)
    sentinel = SentinelBridge(session)
    explainer = CommandExplainer()
    executor = RunnerBridge(session=session) # Execution uses shared session

    while True:
        try:
            # Dynamic Prompt
            prompt_text = "\n[bold green]Intent[/bold green]"
            if session.ghost_mode_active:
                prompt_text = "\n[bold red]⚠️ Ghost Mode ACTIVE[/bold red] | [bold green]Intent[/bold green]"

            user_input = Prompt.ask(prompt_text)
            
            if user_input.lower() in ['exit', 'quit', 'q']:
                break
                
            if not user_input.strip():
                continue

            with console.status("[bold green]Thinking...[/bold green]"):
                intent = parser.resolve_intent(user_input)

            # Security Challenge Check
            if intent.intent_type == "security_challenge_required":
                console.print(f"\n[bold red]🔒 {intent.description}[/bold red]")
                console.print("[yellow]Launching Security Dialog...[/yellow]")
                
                if session.enable_ghost_mode():
                    console.print("[bold green]✅ Security Challenge Passed. Ghost Mode Enabled.[/bold green]")
                    console.print("[dim]Retrying original intent...[/dim]")
                    # Retry resolution with new permissions
                    with console.status("[bold green]Thinking...[/bold green]"):
                        intent = parser.resolve_intent(user_input)
                else:
                    console.print("[bold red]❌ Authorization Denied. Operation blocked.[/bold red]")
                    continue

            # Experimental Mode Join Flow
            if intent.intent_type == "experimental_join":
                console.print("\n[bold red]⚠️  EXPERIMENTAL KERNEL EXTENSION[/bold red]")
                console.print("[yellow]This program enables kernel-assisted experimental features.[/yellow]")
                console.print("[yellow]These features are NOT required for IntentShell.[/yellow]")
                console.print("[red]This mode may:[/red]")
                console.print("[red] - Trigger antivirus alerts[/red]")
                console.print("[red] - Reduce system stability[/red]")
                console.print("[red] - Expose low-level system data[/red]")
                
                # Step 1: Math Challenge
                n1 = random.randint(13, 99)
                n2 = random.randint(17, 88)
                ans = str(n1 + n2)
                
                console.print(f"\n[bold yellow]VERIFICATION REQUIRED: What is {n1} + {n2}?[/bold yellow]")
                math_input = Prompt.ask("Answer")
                
                if math_input.strip() != ans:
                    console.print("[bold red]❌ Incorrect verification. Operation aborted.[/bold red]")
                    continue

                console.print("\n[bold]Type exactly: [/bold][white on red]I AGREE TO USE EXPERIMENTAL KERNEL FEATURES[/white on red]")
                
                confirmation = Prompt.ask("Confirmation")
                
                if confirmation == "I AGREE TO USE EXPERIMENTAL KERNEL FEATURES":
                    current_user = getpass.getuser()
                    console.print(f"\n[bold]Type your OS username to continue ({current_user}):[/bold]")
                    username_input = Prompt.ask("Username")
                    
                    if username_input.lower() == current_user.lower():
                        # Enable Mode
                        session.enable_experimental_mode()
                        console.print("[bold green]✅ Experimental Driver Mode JOINED (Session Scoped).[/bold green]")
                        console.print("[dim]Access to 'experimental/driver' features enabled.[/dim]")
                        
                        # Log
                        with open("audit.log", "a", encoding="utf-8") as f:
                            f.write(f"[{datetime.datetime.now().isoformat()}] USER_JOINED_EXPERIMENTAL_DRIVER_MODE User:{current_user}\n")
                    else:
                        console.print("[bold red]❌ Username mismatch. Operation aborted.[/bold red]")
                else:
                     console.print("[bold red]❌ Incorrect confirmation phrase. Operation aborted.[/bold red]")
                
                continue

            if intent.intent_type == "unknown":
                console.print(f"[red]Could not understand intent.[/red]")
                continue

            # Explain
            explanation = explainer.explain(intent)
            console.print(f"\n{explanation}")

            # Generate Command
            command = generator.get_safe_command(intent)
            console.print(f"[dim]Command: {command}[/dim]")

            # Risk Check & Confirmation via Sentinel (Kernel)
            risk_assessment = sentinel.assess(intent, command)
            
            if risk_assessment.level == RiskLevel.HIGH:
                console.print("[bold red]!!! HIGH RISK ACTION !!![/bold red]")
                for reason in risk_assessment.reasons:
                    console.print(f"[red] - {reason}[/red]")
                    
                if not Confirm.ask("Are you ABSOLUTELY sure?"):
                    console.print("[yellow]Cancelled.[/yellow]")
                    continue
            elif risk_assessment.level == RiskLevel.MEDIUM:
                console.print("[bold yellow]! Medium Risk Action ![/bold yellow]")
                for reason in risk_assessment.reasons:
                    console.print(f"[yellow] - {reason}[/yellow]")
                    
                if not Confirm.ask("Do you want to proceed?"):
                    console.print("[yellow]Cancelled.[/yellow]")
                    continue
            
            # Execution
            # 1. Dry Run
            executor.dry_run(command, intent.description)
            
            # 2. Real Execution (Ask again for MVP safety)
            if Confirm.ask("[bold cyan]Execute Real Command?[/bold cyan]"):
                success = executor.execute(command, intent)
                if success:
                    # Cache successful execution
                    parser.cache_successful_execution(user_input, intent.__dict__)
            else:
                console.print("[yellow]Skipped execution.[/yellow]")

        except KeyboardInterrupt:
            console.print("\n[yellow]Exiting...[/yellow]")
            break
        except Exception as e:
            console.print(f"[bold red]Error:[/bold red] {e}")

if __name__ == "__main__":
    main()
