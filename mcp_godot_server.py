#!/usr/bin/env python3
"""
MCP Server for Godot Auto-Battler Project
Provides tools for AI assistants to interact with the Godot project
"""

import json
import os
import subprocess
import sys
import signal
import time
import atexit
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

import httpx
from mcp.server.fastmcp import FastMCP

# Initialize FastMCP server
mcp = FastMCP("godot-auto-battler")

# Constants
PROJECT_ROOT = Path(__file__).parent
GODOT_PROJECT_FILE = PROJECT_ROOT / "project.godot"
DATA_DIR = PROJECT_ROOT / "data"
TESTS_DIR = PROJECT_ROOT / "tests"

# Process tracking
_active_processes: Set[subprocess.Popen] = set()
_cleanup_registered = False


# Process management functions
def register_cleanup():
    """Register cleanup handlers once."""
    global _cleanup_registered
    if not _cleanup_registered:
        atexit.register(cleanup_all_processes)
        signal.signal(signal.SIGINT, lambda s, f: (cleanup_all_processes(), sys.exit(0)))
        signal.signal(signal.SIGTERM, lambda s, f: (cleanup_all_processes(), sys.exit(0)))
        _cleanup_registered = True


def track_process(process: subprocess.Popen):
    """Track a process for cleanup."""
    _active_processes.add(process)


def untrack_process(process: subprocess.Popen):
    """Remove a process from tracking."""
    _active_processes.discard(process)


def cleanup_all_processes():
    """Clean up all tracked processes."""
    for process in list(_active_processes):
        try:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        except:
            pass
        untrack_process(process)
    
    # Also run general cleanup
    cleanup_godot_processes()


# Helper functions
@contextmanager
def managed_godot_process(args: List[str], cwd: Path):
    """Context manager for running Godot processes with guaranteed cleanup."""
    godot_path = find_godot_executable()
    
    if not godot_path:
        raise RuntimeError(
            "Godot executable not found. Please either:\n"
            "1. Install Godot and ensure it's in your PATH\n"
            "2. Set GODOT_PATH environment variable to point to Godot executable\n"
            "3. Install Godot in /Applications/Godot.app (macOS)"
        )
    
    process = None
    try:
        # Create new process group for better control
        kwargs = {
            'stdout': subprocess.PIPE,
            'stderr': subprocess.PIPE,
            'text': True,
            'cwd': cwd,
        }
        
        # Platform-specific process group handling
        if os.name != 'nt':
            # Unix/macOS: Create new process group
            kwargs['preexec_fn'] = os.setsid
        else:
            # Windows: Create new process group
            kwargs['creationflags'] = subprocess.CREATE_NEW_PROCESS_GROUP
        
        # Start the process
        # --quit-after 1 ensures process exits after completion
        process = subprocess.Popen(
            [godot_path, "--headless", "--quit-after", "1"] + args,
            **kwargs
        )
        
        # Track the process
        track_process(process)
        
        yield process
    finally:
        # Cleanup: ensure process and all children are terminated
        if process:
            try:
                # First, try graceful termination
                if process.poll() is None:
                    if os.name != 'nt':
                        # Unix/macOS: Send SIGTERM to entire process group
                        try:
                            pgid = os.getpgid(process.pid)
                            os.killpg(pgid, signal.SIGTERM)
                        except (ProcessLookupError, OSError):
                            # Process might have already terminated
                            pass
                    else:
                        # Windows: Terminate the process
                        process.terminate()
                    
                    # Give it time to terminate gracefully
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        # Force kill if graceful termination failed
                        if os.name != 'nt':
                            try:
                                pgid = os.getpgid(process.pid)
                                os.killpg(pgid, signal.SIGKILL)
                            except (ProcessLookupError, OSError):
                                pass
                        else:
                            process.kill()
                        
                        # Final wait
                        try:
                            process.wait(timeout=2)
                        except subprocess.TimeoutExpired:
                            # Process is really stuck, log it
                            print(f"Warning: Failed to terminate Godot process {process.pid}", file=sys.stderr)
            except Exception as e:
                print(f"Error during process cleanup: {e}", file=sys.stderr)
            finally:
                # Remove from tracking
                untrack_process(process)


def find_godot_executable() -> Optional[str]:
    """Find Godot executable in common locations."""
    # Check if godot is in PATH
    if subprocess.run(["which", "godot"], capture_output=True).returncode == 0:
        return "godot"
    
    # Common macOS locations
    mac_locations = [
        "/Applications/Godot.app/Contents/MacOS/Godot",
        "/Applications/Godot_v4.app/Contents/MacOS/Godot",
        "/Applications/Godot4.app/Contents/MacOS/Godot",
        os.path.expanduser("~/Applications/Godot.app/Contents/MacOS/Godot"),
    ]
    
    for path in mac_locations:
        if os.path.exists(path):
            return path
    
    # Check environment variable
    if "GODOT_PATH" in os.environ:
        return os.environ["GODOT_PATH"]
    
    return None

def run_godot_command(args: List[str], timeout: int = 60) -> tuple[bool, str, str]:
    """Run a Godot command and return success status, stdout, and stderr."""
    # Always use the safe version with context manager
    return run_godot_command_safe(args, timeout)


def load_json_file(file_path: Path) -> Optional[Dict[str, Any]]:
    """Load and parse a JSON file."""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        return None


def run_godot_command_safe(args: List[str], timeout: int = 60) -> tuple[bool, str, str]:
    """
    Run a Godot command using context manager for guaranteed cleanup.
    This is the preferred method for running Godot processes.
    """
    # Try to use godot_runner if available
    try:
        runner_path = PROJECT_ROOT / "godot_runner.py"
        if runner_path.exists():
            import importlib.util
            spec = importlib.util.spec_from_file_location("godot_runner", runner_path)
            if spec and spec.loader:
                godot_runner = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(godot_runner)
                return godot_runner.run_godot(args, timeout)
    except Exception:
        pass  # Fall back to original method
    
    # Original method with cleanup
    if "--quit" not in args:
        args = ["--quit"] + args
    
    try:
        with managed_godot_process(args, PROJECT_ROOT) as process:
            try:
                stdout, stderr = process.communicate(timeout=timeout)
                returncode = process.returncode
                
                # Always run cleanup after command completes
                cleanup_godot_processes()
                
                return returncode == 0, stdout, stderr
            except subprocess.TimeoutExpired:
                # Cleanup on timeout
                cleanup_godot_processes()
                return False, "", "Command timed out"
    except RuntimeError as e:
        cleanup_godot_processes()
        return False, "", str(e)
    except Exception as e:
        cleanup_godot_processes()
        return False, "", f"Unexpected error: {str(e)}"


def cleanup_godot_processes():
    """Force cleanup any lingering Godot processes."""
    try:
        if os.name != 'nt':
            # Unix/macOS: More aggressive cleanup
            # First, try to kill headless Godot processes
            subprocess.run(["pkill", "-9", "-f", "Godot.*--headless"], capture_output=True)
            # Also kill any Godot processes with --quit flag
            subprocess.run(["pkill", "-9", "-f", "Godot.*--quit"], capture_output=True)
            
            # Additional cleanup using killall (if available)
            try:
                subprocess.run(["killall", "-9", "Godot"], capture_output=True, check=False)
            except FileNotFoundError:
                pass
            
            # Use ps and kill for any remaining processes
            result = subprocess.run(
                ["ps", "aux"], 
                capture_output=True, 
                text=True
            )
            
            if result.returncode == 0:
                for line in result.stdout.splitlines():
                    if "Godot" in line and "--headless" in line:
                        parts = line.split()
                        if len(parts) > 1:
                            pid = parts[1]
                            try:
                                subprocess.run(["kill", "-9", pid], capture_output=True)
                            except:
                                pass
        else:
            # Windows: Use taskkill with more options
            subprocess.run(["taskkill", "/F", "/IM", "Godot.exe"], capture_output=True)
            subprocess.run(["taskkill", "/F", "/IM", "Godot*.exe"], capture_output=True)
            # Also try with process tree
            subprocess.run(["taskkill", "/F", "/T", "/IM", "Godot.exe"], capture_output=True)
    except Exception as e:
        print(f"Cleanup error: {e}", file=sys.stderr)


def save_json_file(file_path: Path, data: Dict[str, Any]) -> bool:
    """Save data to a JSON file."""
    try:
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    except Exception:
        return False


# MCP Tools
@mcp.tool()
async def run_tests(test_pattern: str = "") -> str:
    """
    Run Godot unit tests using GUT framework with proper cleanup.
    
    Args:
        test_pattern: Optional pattern to filter tests (e.g., "test_battle" to run only battle tests)
    """
    # Use GUT with exit flag and add force quit script
    args = ["-s", "res://addons/gut/gut_cmdln.gd", "-gdir=res://tests", "-gexit"]
    
    if test_pattern:
        args.append(f"-gtest={test_pattern}")
    
    # Add force quit script
    args.extend(["--", "--script", "res://tools/diagnostics/force_quit.gd"])
    
    success, stdout, stderr = run_godot_command(args, timeout=120)
    
    # Ensure cleanup after tests
    cleanup_godot_processes()
    
    if success:
        return f"Tests completed successfully:\n{stdout}"
    else:
        return f"Tests failed:\nSTDOUT:\n{stdout}\n\nSTDERR:\n{stderr}"


@mcp.tool()
async def run_scene(scene_path: str, timeout_seconds: int = 30) -> str:
    """
    Run a specific Godot scene with proper cleanup.
    
    Args:
        scene_path: Path to the scene file (e.g., "res://scenes/tests/battle_test.tscn")
        timeout_seconds: How long to run the scene before stopping (max 300 seconds)
    """
    # Cap timeout to prevent excessive resource usage
    timeout_seconds = min(timeout_seconds, 300)
    
    # Add --quit flag to ensure Godot exits cleanly
    args = ["--quit", "--", scene_path]
    success, stdout, stderr = run_godot_command(args, timeout=timeout_seconds)
    
    if success or "timeout" in stderr.lower():
        return f"Scene ran for up to {timeout_seconds} seconds:\n{stdout}"
    else:
        return f"Scene failed to run:\nSTDOUT:\n{stdout}\n\nSTDERR:\n{stderr}"


@mcp.tool()
async def check_script_errors() -> str:
    """
    Check all GDScript files for syntax errors with proper cleanup.
    """
    args = ["--script", "res://tools/testing/check_gut.gd", "--check-only", "--quit"]
    success, stdout, stderr = run_godot_command(args, timeout=60)
    
    # Ensure cleanup
    cleanup_godot_processes()
    
    if success:
        return "No script errors found"
    else:
        return f"Script errors found:\n{stderr}"


@mcp.tool()
async def get_encounter_data() -> str:
    """
    Get all encounter configurations from the encounters.json file.
    """
    encounters_file = DATA_DIR / "encounters.json"
    data = load_json_file(encounters_file)
    
    if data is None:
        return "Failed to load encounters.json"
    
    summary = []
    summary.append(f"Total encounters: {len(data.get('encounters', []))}")
    
    for encounter in data.get('encounters', []):
        enc_info = [
            f"\nEncounter: {encounter.get('id', 'Unknown')}",
            f"  Name: {encounter.get('name', 'Unknown')}",
            f"  Difficulty: {encounter.get('difficulty', 'Unknown')}",
            f"  Waves: {len(encounter.get('waves', []))}"
        ]
        summary.extend(enc_info)
    
    return "\n".join(summary)


@mcp.tool()
async def get_unit_templates() -> str:
    """
    Get all unit template configurations from unit_templates.json.
    """
    templates_file = DATA_DIR / "unit_templates.json"
    data = load_json_file(templates_file)
    
    if data is None:
        return "Failed to load unit_templates.json"
    
    summary = []
    summary.append(f"Total unit templates: {len(data.get('units', []))}")
    
    for unit in data.get('units', []):
        unit_info = [
            f"\nUnit: {unit.get('id', 'Unknown')}",
            f"  Name: {unit.get('name', 'Unknown')}",
            f"  Type: {unit.get('type', 'Unknown')}",
            f"  HP: {unit.get('base_stats', {}).get('max_hp', 0)}",
            f"  Damage: {unit.get('base_stats', {}).get('damage', 0)}"
        ]
        summary.extend(unit_info)
    
    return "\n".join(summary)


@mcp.tool()
async def add_unit_template(
    unit_id: str,
    name: str,
    unit_type: str,
    max_hp: int,
    damage: int,
    armor: int = 0,
    speed: int = 100
) -> str:
    """
    Add a new unit template to the unit_templates.json file.
    
    Args:
        unit_id: Unique identifier for the unit
        name: Display name of the unit
        unit_type: Type of unit (e.g., "warrior", "mage", "archer")
        max_hp: Maximum health points
        damage: Base damage value
        armor: Armor value (default: 0)
        speed: Movement/action speed (default: 100)
    """
    templates_file = DATA_DIR / "unit_templates.json"
    data = load_json_file(templates_file)
    
    if data is None:
        return "Failed to load unit_templates.json"
    
    # Check if unit already exists
    existing_units = data.get('units', [])
    if any(unit['id'] == unit_id for unit in existing_units):
        return f"Unit with ID '{unit_id}' already exists"
    
    # Create new unit
    new_unit = {
        "id": unit_id,
        "name": name,
        "type": unit_type,
        "base_stats": {
            "max_hp": max_hp,
            "damage": damage,
            "armor": armor,
            "speed": speed
        },
        "skills": [],
        "equipment_slots": ["weapon", "armor", "accessory"]
    }
    
    existing_units.append(new_unit)
    data['units'] = existing_units
    
    if save_json_file(templates_file, data):
        return f"Successfully added unit template '{name}' with ID '{unit_id}'"
    else:
        return "Failed to save unit template"


@mcp.tool()
async def create_encounter(
    encounter_id: str,
    name: str,
    difficulty: str,
    wave_configs: List[Dict[str, Any]]
) -> str:
    """
    Create a new encounter configuration.
    
    Args:
        encounter_id: Unique identifier for the encounter
        name: Display name of the encounter
        difficulty: Difficulty level (easy, normal, hard, elite, boss)
        wave_configs: List of wave configurations, each containing unit_ids and counts
    
    Example wave_configs:
    [
        {"units": [{"unit_id": "goblin", "count": 3}]},
        {"units": [{"unit_id": "goblin", "count": 2}, {"unit_id": "goblin_chief", "count": 1}]}
    ]
    """
    encounters_file = DATA_DIR / "encounters.json"
    data = load_json_file(encounters_file)
    
    if data is None:
        return "Failed to load encounters.json"
    
    # Check if encounter already exists
    existing_encounters = data.get('encounters', [])
    if any(enc['id'] == encounter_id for enc in existing_encounters):
        return f"Encounter with ID '{encounter_id}' already exists"
    
    # Create new encounter
    new_encounter = {
        "id": encounter_id,
        "name": name,
        "difficulty": difficulty,
        "waves": []
    }
    
    # Build waves
    for i, wave_config in enumerate(wave_configs):
        wave = {
            "wave_number": i + 1,
            "units": wave_config.get("units", [])
        }
        new_encounter["waves"].append(wave)
    
    existing_encounters.append(new_encounter)
    data['encounters'] = existing_encounters
    
    if save_json_file(encounters_file, data):
        return f"Successfully created encounter '{name}' with {len(wave_configs)} waves"
    else:
        return "Failed to save encounter"


@mcp.tool()
async def get_project_structure() -> str:
    """
    Get an overview of the Godot project structure.
    """
    structure = []
    
    # Key directories
    dirs_to_check = [
        ("Scripts", "*.gd"),
        ("Tests", "tests/**/*.gd"),
        ("Data", "data/*.json"),
        ("Scenes", "*.tscn"),
        ("Addons", "addons/*")
    ]
    
    for label, pattern in dirs_to_check:
        files = list(PROJECT_ROOT.glob(pattern))
        structure.append(f"\n{label}: {len(files)} files")
        for file in files[:5]:  # Show first 5 files
            structure.append(f"  - {file.name}")
        if len(files) > 5:
            structure.append(f"  ... and {len(files) - 5} more")
    
    return "\n".join(structure)


@mcp.tool()
async def cleanup_processes() -> str:
    """
    Manually trigger cleanup of any lingering Godot processes.
    This is useful if processes were left running from previous operations.
    """
    cleanup_godot_processes()
    return "Cleanup completed. Any lingering Godot processes have been terminated."


@mcp.tool()
async def validate_battle_rules() -> str:
    """
    Validate the battle rules configuration file.
    """
    rules_file = PROJECT_ROOT / "battle_rules.json"
    data = load_json_file(rules_file)
    
    if data is None:
        return "Failed to load battle_rules.json"
    
    validation_results = []
    
    # Check for required fields
    required_fields = ["rules"]
    for field in required_fields:
        if field in data:
            validation_results.append(f"✓ Found '{field}' field")
        else:
            validation_results.append(f"✗ Missing required field '{field}'")
    
    # Validate rules
    if "rules" in data:
        rules_count = len(data["rules"])
        validation_results.append(f"\nTotal rules: {rules_count}")
        
        for rule in data["rules"][:3]:  # Show first 3 rules
            rule_info = [
                f"\nRule: {rule.get('id', 'Unknown')}",
                f"  Priority: {rule.get('priority', 'Not set')}",
                f"  Conditions: {len(rule.get('conditions', []))}",
                f"  Actions: {len(rule.get('actions', []))}"
            ]
            validation_results.extend(rule_info)
    
    return "\n".join(validation_results)


if __name__ == "__main__":
    # Check if we're in the right directory
    if not GODOT_PROJECT_FILE.exists():
        print(f"Error: project.godot not found at {GODOT_PROJECT_FILE}", file=sys.stderr)
        print("Please run this script from the Godot project root directory", file=sys.stderr)
        sys.exit(1)
    
    # Register cleanup handlers
    register_cleanup()
    
    # Run the MCP server
    mcp.run(transport='stdio')