"""
KERNEL MODE IS INTENTIONALLY DISABLED.

This module exists as a permanent safety gate.
Any attempt to enable kernel mode is blocked by design.

# This module is evaluated at import-time.
# Any attempt to bypass kernel restrictions must modify source code.
"""

KERNEL_MODE_AVAILABLE = False
KERNEL_MODE_REASON = "Disabled by design for security & repository compliance"

def assert_kernel_disabled():
    """
    Raises a RuntimeError to prevent kernel mode execution.
    This function should be called at any entry point that attempts to use kernel features.
    """
    raise RuntimeError(
        "Kernel mode is permanently disabled in this build.\n"
        "This is an intentional design decision."
    )
