import sys
import os
import pytest

# Add project root to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.security.kernel_guard import assert_kernel_disabled, KERNEL_MODE_AVAILABLE

def test_kernel_is_disabled():
    """
    Verifies that the kernel mode is permanently disabled and the guard raises an error.
    """
    assert KERNEL_MODE_AVAILABLE is False, "KERNEL_MODE_AVAILABLE flag must be False"
    
    with pytest.raises(RuntimeError) as excinfo:
        assert_kernel_disabled()
    
    assert "permanently disabled" in str(excinfo.value)
    assert "intentional design decision" in str(excinfo.value)

def test_powershell_session_init_has_disabled_flags():
    """
    Checks if the PowerShell session initialization script has the correct disabled flags.
    This is a static analysis of the code string in powershell_session.py.
    """
    from core.powershell_session import PowerShellSession
    import inspect
    
    # We can't easily instantiate the session without starting a process, 
    # but we can inspect the source code or the _start_session method logic if we refactor.
    # For now, let's just ensure the guard is imported in the file.
    
    # Use absolute path based on __file__
    session_file_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "core", "powershell_session.py")
    
    with open(session_file_path, "r", encoding="utf-8") as f:
        content = f.read()
        
    assert "from .security.kernel_guard import assert_kernel_disabled" in content or "from core.security.kernel_guard import assert_kernel_disabled" in content
    assert "assert_kernel_disabled()" in content
