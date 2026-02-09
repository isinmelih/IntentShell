# Security Policy

## Supported Versions

Use the latest version of IntentShell to ensure you have the most up-to-date security patches.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

Please report vulnerabilities by opening an issue or contacting the maintainers directly.

## Telemetry

IntentShell does not collect telemetry or user data.

## Kernel Mode Policy

**Kernel-level execution is explicitly out of scope for this project.**

This project intentionally excludes all kernel-level, driver-based, or ring-0 functionality from the public repository.

While the repository may contain archival code references to kernel drivers or low-level system interactions (located in `_dormant` directories), these components are:

1.  **Disabled by default.**
2.  **Guarded by a hard-coded kill switch.**
3.  **Unreachable via configuration, environment variables, or runtime flags.**

Any attempt to enable these features requires modifying the source code and removing explicit security guards.
