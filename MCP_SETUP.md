# MCP (Model Context Protocol) Integration for Godot Auto-Battler

This project includes an MCP server that allows AI assistants like OpenCode and Claude Desktop to interact with your Godot project through standardized tools.

## Features

The MCP server provides the following tools:

### Testing & Validation
- **run_tests**: Run GUT unit tests with optional filtering (auto-cleanup after completion)
- **check_script_errors**: Check all GDScript files for syntax errors (runs with --quit flag)
- **validate_battle_rules**: Validate the battle rules configuration

### Scene Management
- **run_scene**: Run specific Godot scenes with timeout control (max 300 seconds)
- **cleanup_processes**: Manually clean up any lingering Godot processes

### Data Management
- **get_encounter_data**: View all encounter configurations
- **get_unit_templates**: View all unit templates
- **add_unit_template**: Add new unit templates to the game
- **create_encounter**: Create new encounter configurations

### Project Navigation
- **get_project_structure**: Get an overview of the project structure

## Quick Setup for OpenCode

1. Run setup: `./setup_mcp.sh`
2. Add to OpenCode config (`~/.config/opencode/config.json`):
   ```json
   {
     "mcpServers": {
       "godot-auto-battler": {
         "command": "python",
         "args": ["/Users/orion/Work/Orion/godot-auto-battler-projector/mcp_godot_server.py"],
         "env": {
           "PYTHONPATH": "/Users/orion/Work/Orion/godot-auto-battler-projector/venv/lib/python3.*/site-packages"
         }
       }
     }
   }
   ```
3. Restart OpenCode

## Detailed Setup Instructions

### Prerequisites
- Python 3.10 or higher
- Godot 4.x installed (see Godot Configuration below)
- Claude Desktop or OpenCode (for testing with AI assistants)

### Godot Configuration

The MCP server needs to find your Godot installation. Run the configuration helper:
```bash
./configure_godot.sh
```

This script will:
- Check if Godot is already in your PATH
- Search common installation locations
- Provide setup instructions if Godot isn't found

The MCP server checks for Godot in this order:
1. `godot` command in your PATH
2. Common macOS locations (/Applications/Godot.app)
3. GODOT_PATH environment variable

If Godot isn't found automatically, set the GODOT_PATH environment variable:
```bash
# Add to your shell profile (~/.zshrc or ~/.bash_profile)
export GODOT_PATH="/path/to/your/godot/executable"
```

### Installation

1. **Run the setup script**:
   ```bash
   ./setup_mcp.sh
   ```

   This will:
   - Verify Python version
   - Create a virtual environment
   - Install required dependencies (mcp, httpx)

2. **Configure your AI assistant client**:

   ### For OpenCode:
   
   Add to your OpenCode configuration file (`~/.config/opencode/config.json`):
   ```json
   {
     "mcpServers": {
       "godot-auto-battler": {
         "command": "python",
         "args": [
           "/Users/orion/Work/Orion/godot-auto-battler-projector/mcp_godot_server.py"
         ],
         "env": {
           "PYTHONPATH": "/Users/orion/Work/Orion/godot-auto-battler-projector/venv/lib/python3.*/site-packages"
         }
       }
     }
   }
   ```
   
   Then restart OpenCode or reload the configuration.

   ### For Claude Desktop:
   
   Copy the configuration to Claude's config directory:
   ```bash
   cp claude_desktop_config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```
   
   Or manually add to your existing config:
   ```json
   {
     "mcpServers": {
       "godot-auto-battler": {
         "command": "python",
         "args": [
           "/Users/orion/Work/Orion/godot-auto-battler-projector/mcp_godot_server.py"
         ]
       }
     }
   }
   ```

3. **Restart your client** (OpenCode or Claude Desktop) to pick up the new server configuration.

## Running the Server

### Standalone Mode
```bash
source venv/bin/activate
python mcp_godot_server.py
```

### With OpenCode or Claude Desktop
Once configured, your AI assistant client will automatically start the server when needed.

## Using the Tools

In OpenCode or Claude Desktop, you can use natural language to interact with your Godot project:

- "Run the battle tests"
- "Show me all the unit templates"
- "Create a new goblin warrior unit with 50 HP and 10 damage"
- "Check for script errors in the project"
- "Run the battle_test scene for 10 seconds"

## Troubleshooting

### Server not showing up in your AI assistant

#### For OpenCode:
1. Check OpenCode logs for MCP-related errors
2. Verify the absolute path in `~/.config/opencode/config.json` is correct
3. Ensure the PYTHONPATH environment variable points to your venv
4. Try running the server manually to test: `source venv/bin/activate && python mcp_godot_server.py`

#### For Claude Desktop:
1. Check `~/Library/Logs/Claude/mcp*.log` for errors
2. Verify the absolute path in the config is correct
3. Ensure the virtual environment was created successfully

### Godot commands failing
1. Ensure `godot` command is available in your PATH
2. Check that you're running from the project root directory
3. Verify project.godot exists

### Python import errors
1. Make sure you activated the virtual environment
2. Re-run `pip install -r requirements.txt`
3. Check Python version is 3.10+

### Memory leaks or lingering processes
The MCP server now includes comprehensive process cleanup to prevent memory leaks:
- All Godot processes are terminated after command completion
- Process tracking ensures all spawned processes are monitored
- Timeout handling with forced termination for stuck processes
- Process groups are used to ensure child processes are also terminated
- Manual cleanup available via the `cleanup_processes` tool
- Cleanup scripts: `./cleanup_godot.sh` for aggressive manual cleanup
- Enhanced test runner script with automatic cleanup on exit
- Signal handlers ensure cleanup on interruption (Ctrl+C)

Note: The "Import could not be resolved" error in your editor is normal before running the setup script. The MCP package will be installed in the virtual environment when you run `./setup_mcp.sh`.

## Extending the Server

To add new tools, edit `mcp_godot_server.py` and add new functions decorated with `@mcp.tool()`:

```python
@mcp.tool()
async def your_new_tool(param1: str, param2: int) -> str:
    """
    Tool description that will be shown to the AI.
    
    Args:
        param1: Description of first parameter
        param2: Description of second parameter
    """
    # Your tool implementation
    return "Result"
```

## Security Notes

- The server runs locally and only exposes tools to interact with your Godot project
- Be cautious about what operations you expose through MCP tools
- The server uses subprocess to run Godot commands with timeouts for safety