#!/usr/bin/env python3
"""
Godot runner with robust process management.
This script ensures Godot processes are properly terminated.
"""

import os
import subprocess
import sys
import signal
import time
import atexit
from pathlib import Path

# Track child processes
child_processes = []

def cleanup():
    """Clean up all child processes."""
    for proc in child_processes:
        try:
            if proc.poll() is None:
                # Try graceful termination first
                proc.terminate()
                try:
                    proc.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    # Force kill if needed
                    proc.kill()
                    proc.wait()
        except:
            pass
    
    # Additional cleanup for any stragglers
    if sys.platform != "win32":
        subprocess.run(["pkill", "-9", "-f", "Godot.*--headless"], capture_output=True)
        subprocess.run(["pkill", "-9", "-f", "godot.*--headless"], capture_output=True)

# Register cleanup
atexit.register(cleanup)
signal.signal(signal.SIGINT, lambda s, f: (cleanup(), sys.exit(0)))
signal.signal(signal.SIGTERM, lambda s, f: (cleanup(), sys.exit(0)))

def run_godot(args, timeout=60):
    """Run Godot with proper process management."""
    godot_cmd = find_godot()
    if not godot_cmd:
        return False, "", "Godot not found"
    
    # Always add cleanup flags
    full_args = [godot_cmd, "--headless", "--quit", "--no-window"] + args
    
    # Create process with new process group
    kwargs = {
        'stdout': subprocess.PIPE,
        'stderr': subprocess.PIPE,
        'text': True,
    }
    
    if sys.platform != "win32":
        kwargs['preexec_fn'] = os.setsid
    
    proc = subprocess.Popen(full_args, **kwargs)
    child_processes.append(proc)
    
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
        return proc.returncode == 0, stdout, stderr
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
        return False, "", "Timeout"
    finally:
        # Ensure process is removed from tracking
        if proc in child_processes:
            child_processes.remove(proc)

def find_godot():
    """Find Godot executable."""
    # Check PATH
    if subprocess.run(["which", "godot"], capture_output=True).returncode == 0:
        return "godot"
    
    # Check common locations
    locations = [
        "/Applications/Godot.app/Contents/MacOS/Godot",
        "/usr/local/bin/godot",
        os.path.expanduser("~/Applications/Godot.app/Contents/MacOS/Godot"),
    ]
    
    for loc in locations:
        if os.path.exists(loc):
            return loc
    
    return None

if __name__ == "__main__":
    # This script is meant to be imported by mcp_godot_server.py
    # But can be tested standalone
    if len(sys.argv) > 1:
        success, stdout, stderr = run_godot(sys.argv[1:])
        print(stdout)
        if stderr:
            print(stderr, file=sys.stderr)
        sys.exit(0 if success else 1)