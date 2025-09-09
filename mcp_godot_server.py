#!/usr/bin/env python3
"""
MCP Server for Godot Auto-Battler Project
Provides tools for AI assistants to interact with the Godot project
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import httpx
from mcp.server.fastmcp import FastMCP

# Initialize FastMCP server
mcp = FastMCP("godot-auto-battler")

# Constants
PROJECT_ROOT = Path(__file__).parent
GODOT_PROJECT_FILE = PROJECT_ROOT / "project.godot"
DATA_DIR = PROJECT_ROOT / "data"
TESTS_DIR = PROJECT_ROOT / "tests"


# Helper functions
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
    godot_path = find_godot_executable()
    
    if not godot_path:
        error_msg = (
            "Godot executable not found. Please either:\n"
            "1. Install Godot and ensure it's in your PATH\n"
            "2. Set GODOT_PATH environment variable to point to Godot executable\n"
            "3. Install Godot in /Applications/Godot.app (macOS)"
        )
        return False, "", error_msg
    
    try:
        result = subprocess.run(
            [godot_path, "--headless"] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=PROJECT_ROOT
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)


def load_json_file(file_path: Path) -> Optional[Dict[str, Any]]:
    """Load and parse a JSON file."""
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        return None


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
    Run Godot unit tests using GUT framework.
    
    Args:
        test_pattern: Optional pattern to filter tests (e.g., "test_battle" to run only battle tests)
    """
    args = ["-s", "res://addons/gut/gut_cmdln.gd", "-gdir=res://tests", "-gexit"]
    
    if test_pattern:
        args.append(f"-gtest={test_pattern}")
    
    success, stdout, stderr = run_godot_command(args, timeout=120)
    
    if success:
        return f"Tests completed successfully:\n{stdout}"
    else:
        return f"Tests failed:\nSTDOUT:\n{stdout}\n\nSTDERR:\n{stderr}"


@mcp.tool()
async def run_scene(scene_path: str, timeout_seconds: int = 30) -> str:
    """
    Run a specific Godot scene.
    
    Args:
        scene_path: Path to the scene file (e.g., "res://battle_test.tscn")
        timeout_seconds: How long to run the scene before stopping
    """
    args = ["--", scene_path]
    success, stdout, stderr = run_godot_command(args, timeout=timeout_seconds)
    
    if success or "timeout" in stderr.lower():
        return f"Scene ran for {timeout_seconds} seconds:\n{stdout}"
    else:
        return f"Scene failed to run:\nSTDOUT:\n{stdout}\n\nSTDERR:\n{stderr}"


@mcp.tool()
async def check_script_errors() -> str:
    """
    Check all GDScript files for syntax errors.
    """
    args = ["--script", "res://check_gut.gd", "--check-only"]
    success, stdout, stderr = run_godot_command(args, timeout=60)
    
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
    
    # Run the MCP server
    mcp.run(transport='stdio')