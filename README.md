# IntentShell

> **"Intent as a structured, verifiable contract before execution."**

**IntentShell** is a **Cognitive PowerShell Environment** that transforms natural language user intent
(e.g. *“Build the project and analyze errors”*) into **secure, auditable, and transparent system operations**.

This is **not** a simple text-to-command tool.  
IntentShell is a living runtime environment that can reason about actions, learn from past behavior
(Intent DNA), self-correct on failure, and inspect every execution step.
IntentShell is **not** an LLM-centric assistant.
It is a native module-centric system where users directly control, extend, and master PowerShell operations.

---

## What Can I Do with IntentShell?

- Gaining full mastery of PowerShell and unlocking its hidden power.
- Execute system tasks safely using natural language
- Inspect, simulate, approve, or reject commands before execution
- Learn and adapt to your workflow without compromising security
- Replay past executions deterministically for debugging and auditing
- Prevent destructive or malicious behavior with transparent explanations

---

## Core Philosophy: Managed Execution

IntentShell never executes arbitrary commands blindly.  
Every action is born as an **ExecutionPlan** and must pass a strict lifecycle.

### Execution Lifecycle

The system does not simply “run” a command — it **governs** it:

- **Planned** — Intent understood, execution plan created
- **Approved** — SystemGovernor and security policies approve
- **Executing** — Operation is currently running
- **Completed** — Successfully finished
- **Failed** — An error occurred (auto-repair may activate)
- **RolledBack** — Operation reverted

---

## Deterministic Replay & Time Travel

The question *“Why did this command work yesterday but fail today?”* is no longer relevant.

- **Snapshot Context**  
  Environment variables, paths, and execution context are captured per run.

- **Replay**  
  Any previous execution can be replayed under identical conditions.

---

## Intent DNA (Evolutionary Learning)

IntentShell evolves with you.

- **Learning**  
  Frequently used intents and parameters are stored in the memory.

- **Adaptation**  
  When you say *“clean logs”*, the system gradually learns your project-specific log directories.

- **Confidence Scoring**  
  Every decision receives a confidence score (0–100).  
  Low-confidence actions require explicit user confirmation.

---

## Architecture: SystemCore

At the heart of IntentShell lies **SystemCore**.  
All modules communicate **only** with SystemCore — never directly with the external system.

### Execution Pipeline

The journey from intent to reality:

1. **NLU Bridge (Python)**  
   Converts natural language into structured JSON intent.

2. **ContextMood**  
   Analyzes the environment’s “mood” (e.g. *Deep Work*, *Casual*).

3. **SystemGovernor**  
   Determines whether the action is safe to execute (has veto power).

4. **SystemCore**
   - **Internal Delegation** — Routes execution to the correct module
   - **Shadow Execution** — Simulates risky operations
   - **Execution** — Performs the actual operation

5. **SessionMemory & IntentLearning**  
   Stores results in memory and Intent DNA.

6. **ProactiveSuggestion**  
   Suggests next steps based on learned behavior.

---

## Security & Licensing Model (Future-Proof Free)

IntentShell follows the principle:

> **"Code is always open"**

### Core vs Policy Separation

- **Core Engine (Apache 2.0 / MIT)**  
  Open-source execution engine.  
  Executes commands but does **not** decide what is safe.

---

### User Macros


IntentShell introduces command reduction via `#variablename`, allowing complex multi-step commands to be executed using a single, human-friendly keyword.

### Kernel Mode Notice

IntentShell does **not** support kernel-mode execution.

Any kernel-related code present in this repository:
- is intentionally dormant
- is unreachable by design
- exists for research and future planning only

---

### Shadow Execution

> *“What would happen if I ran this command?”*

IntentShell can simulate actions before execution:
- files are not deleted
- services are not stopped
- only outcomes are reported

---

## Module Ecosystem

IntentShell consists of independent, capability-based modules
implementing the **SystemModule** interface.

### Intelligence & Learning

- **IntentLearning.psm1** — Intent DNA and user behavior
- **ContextAwareness.psm1** — Project, time, and Git state awareness
- **ProactiveSuggestion.psm1** — Predictive next-step suggestions
- **DecisionExplainer.psm1** — Transparent decision explanations

### Creative & Flow

- **CreativeCore.psm1** — Base for creative modules
- **CreativeStudio.psm1** — Perspective shifts and *What-If* scenarios
- **FlowState.psm1** — Focus and productivity modes
- **IdeaScratchpad.psm1** — Rapid idea capture

### Utility & Operations

- **FileOperations.psm1** — Smart file operations (regex rename, secure delete)
- **NetworkAwareness.psm1** — Network state and port analysis
- **ProcessIntelligence.psm1** — Process tree inspection
- **AutoFix.psm1** — Log analysis and auto-remediation
- **EnvManager.psm1** — Virtual environment management

### Core System

- **SystemCore.psm1** — Orchestrator
- **SystemGovernor.psm1** — Security authority
- **PathResolution.psm1** — Intelligent path resolution
- **SafetyCheck.psm1** — Dangerous pattern detection

---

## Testing & Resilience

IntentShell is designed with production-level resilience.

> **"IntentShell includes resilience tests for stalled PowerShell sessions and malformed UTF-8 output."**

- **Resilience Tests**  
  Prevent crashes when PowerShell sessions stall, loop infinitely, or emit invalid UTF-8.

- **Timeout Recovery**  
  Non-responsive subprocesses are terminated and recovered automatically.

---

## Known Limitations

> **"Intent resolution is rule-based and optimized for common system diagnostics queries."**

- **Rule-Based NLU**  
  Current intent resolution relies on deterministic regex rules and keyword matching.

- **Safe Fallback Mode**  
  Ambiguous or conversational inputs fall back to **System Diagnostics Mode**
  instead of risking unsafe execution.

---

## Getting Started

### Requirements

- PowerShell 5.1 or 7+
- Python 3.10+ (for the NLU bridge)
- Administrator privileges (for certain system modules)

### Installation & Execution

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-repo/IntentShell.git
   cd IntentShell
Start the Engine

.\Start-IntentShellEngine.ps1
Example Commands

"Clean log files on desktop" → FileOperations

"Why is this project running so slowly?" → Performance analysis

"Switch to creative mode" → FlowState & CreativeStudio

Project Status
Version: v1.0.0 (Stable)

License:

Code: Apache 2.0 / MIT

Policy: Safety Always Wins!

Author: You

IntentShell — because computers should understand what you mean, not just what you type
