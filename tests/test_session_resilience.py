import pytest
import time
import subprocess
from core.powershell_session import PowerShellSession

class TestSessionResilience:
    @pytest.fixture(scope="function")
    def session(self):
        """Creates a fresh PowerShell session for each test."""
        session = PowerShellSession()
        yield session
        session.close()

    def test_basic_execution(self, session):
        """Test simple command execution."""
        output = session.run_command("Write-Output 'Hello World'")
        assert "Hello World" in output

    def test_utf8_encoding(self, session):
        """Test handling of Turkish characters."""
        test_str = "Şekerli Çay Ğüzeldir İıÖöÇçŞş"
        output = session.run_command(f"Write-Output '{test_str}'")
        assert test_str in output

    def test_variable_persistence(self, session):
        """Test that variables persist across commands."""
        session.run_command("$x = 42")
        output = session.run_command("Write-Output $x")
        assert "42" in output

    def test_error_capture(self, session):
        """Test that PowerShell errors are captured gracefully."""
        output = session.run_command("Get-Item 'NonExistentPath_XYZ'")
        # The wrapper in powershell_session.py catches errors and prints "ERROR: ..."
        assert "ERROR:" in output or "Cannot find path" in output

    def test_process_recovery(self, session):
        """Test recovery when the underlying pwsh process is killed."""
        # 1. Verify session is alive
        pid_out = session.run_command("$PID")
        assert pid_out.strip().isdigit()
        original_pid = int(pid_out.strip())

        # 2. Kill the process manually
        print(f"Killing PID: {original_pid}")
        subprocess.run(["taskkill", "/F", "/PID", str(original_pid)], capture_output=True)
        
        # Wait a moment for OS to register death
        time.sleep(1)

        # 3. Run a new command. The session should detect death and restart.
        # Note: The first attempt might fail or just restart. 
        # The code says: if process.poll() is not None -> restart.
        new_pid_out = session.run_command("$PID")
        
        assert new_pid_out.strip().isdigit()
        new_pid = int(new_pid_out.strip())
        
        assert new_pid != original_pid
        print(f"Recovered with new PID: {new_pid}")

    def test_timeout_handling(self, session):
        """Test that long running commands trigger a timeout."""
        # Temporarily lower timeout for test speed
        session.read_timeout_seconds = 2
        
        # Run a command that sleeps for 5 seconds
        start_time = time.time()
        output = session.run_command("Start-Sleep -Seconds 5; Write-Output 'Done'")
        duration = time.time() - start_time
        
        # Should finish near 2 seconds, not 5
        assert duration < 4 
        assert "TIMEOUT" in output
