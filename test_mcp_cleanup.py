#!/usr/bin/env python3
"""
Test script to verify MCP server properly cleans up Godot processes
"""

import asyncio
import subprocess
import sys
import time

async def test_cleanup():
    """Test that Godot processes are properly cleaned up."""
    print("Testing MCP server process cleanup...")
    
    # Check for any existing Godot processes
    def count_godot_processes():
        try:
            result = subprocess.run(
                ["pgrep", "-f", "Godot.*--headless"],
                capture_output=True,
                text=True
            )
            return len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
        except:
            return 0
    
    initial_count = count_godot_processes()
    print(f"Initial Godot processes: {initial_count}")
    
    # Import and use the MCP server functions directly
    sys.path.insert(0, '.')
    from mcp_godot_server import run_godot_command, cleanup_godot_processes
    
    # Test 1: Run a command that should terminate quickly
    print("\nTest 1: Running quick command...")
    success, stdout, stderr = run_godot_command(["--version"], timeout=5)
    time.sleep(1)
    
    after_quick = count_godot_processes()
    print(f"Processes after quick command: {after_quick}")
    
    # Test 2: Run a command that will timeout
    print("\nTest 2: Running command that will timeout...")
    success, stdout, stderr = run_godot_command(["--"], timeout=3)
    time.sleep(1)
    
    after_timeout = count_godot_processes()
    print(f"Processes after timeout: {after_timeout}")
    
    # Test 3: Manual cleanup
    print("\nTest 3: Running manual cleanup...")
    cleanup_godot_processes()
    time.sleep(1)
    
    final_count = count_godot_processes()
    print(f"Processes after cleanup: {final_count}")
    
    if final_count > initial_count:
        print("\n❌ FAILED: Godot processes were not properly cleaned up!")
        return False
    else:
        print("\n✅ SUCCESS: All Godot processes were properly cleaned up!")
        return True

if __name__ == "__main__":
    success = asyncio.run(test_cleanup())
    sys.exit(0 if success else 1)