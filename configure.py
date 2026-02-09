import os
import sys

# Try to import rich for better UI, fallback to standard input
try:
    from rich.console import Console
    from rich.prompt import Prompt
    console = Console()
    USE_RICH = True
except ImportError:
    USE_RICH = False

def main():
    if USE_RICH:
        console.print("[bold blue]IntentShell Configuration[/bold blue]", justify="center")
        console.print("This script will help you configure your API keys.\n")
    else:
        print("IntentShell Configuration")
        print("This script will help you configure your API keys.\n")

    env_path = ".env"
    current_key = ""

    # Check for existing .env
    if os.path.exists(env_path):
        with open(env_path, "r") as f:
            for line in f:
                if line.startswith("GROQ_API_KEY="):
                    current_key = line.strip().split("=", 1)[1]
                    break
    
    if current_key:
        if USE_RICH:
            console.print(f"[yellow]Current API Key found:[/yellow] {current_key[:4]}...{current_key[-4:]}")
            if not Prompt.ask("Do you want to update it?", choices=["y", "n"], default="n") == "y":
                console.print("[green]Configuration unchanged. Exiting.[/green]")
                return
        else:
            print(f"Current API Key found: {current_key[:4]}...{current_key[-4:]}")
            choice = input("Do you want to update it? (y/n) [n]: ").strip().lower()
            if choice != 'y':
                print("Configuration unchanged. Exiting.")
                return

    # Ask for new key
    if USE_RICH:
        # password=False so user can see what they type (avoids confusion)
        new_key = Prompt.ask("[bold green]Enter your Groq API Key[/bold green] (Input will be visible)", password=False)
    else:
        new_key = input("Enter your Groq API Key: ").strip()

    if not new_key:
        if USE_RICH:
            console.print("[red]No key entered. Exiting.[/red]")
        else:
            print("No key entered. Exiting.")
        return

    # Write to .env
    # We'll rewrite the file or update the line. For simplicity, let's just write/append.
    # A robust way is to read all lines, update the key, or append if not found.
    
    lines = []
    if os.path.exists(env_path):
        with open(env_path, "r") as f:
            lines = f.readlines()
    
    key_updated = False
    new_lines = []
    for line in lines:
        if line.startswith("GROQ_API_KEY="):
            new_lines.append(f"GROQ_API_KEY={new_key}\n")
            key_updated = True
        else:
            new_lines.append(line)
    
    if not key_updated:
        if new_lines and not new_lines[-1].endswith("\n"):
            new_lines[-1] += "\n"
        new_lines.append(f"GROQ_API_KEY={new_key}\n")

    with open(env_path, "w") as f:
        f.writelines(new_lines)

    if USE_RICH:
        console.print(f"\n[bold green]Success![/bold green] API Key saved to {os.path.abspath(env_path)}")
        console.print("You can now restart IntentShell.")
    else:
        print(f"\nSuccess! API Key saved to {os.path.abspath(env_path)}")
        print("You can now restart IntentShell.")

    # Pause to let user read
    if not USE_RICH:
        input("\nPress Enter to exit...")
    else:
        Prompt.ask("\nPress Enter to exit")

if __name__ == "__main__":
    main()
