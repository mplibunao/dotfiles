# AeroSpace Layout Manager

Save and restore workspace routing (app → workspace assignments).

## Quick Start

```fish
# Save current layout
aerospace-layout save coding

# Restore a layout
aerospace-layout restore coding

# List saved layouts
aerospace-layout list
```

## Commands

| Command | Description |
|---------|-------------|
| `save <name>` | Save current window arrangement |
| `restore <name>` | Restore a saved layout |
| `restore <name> --dry-run` | Preview restore without changes |
| `restore <name> --launch` | Launch missing apps during restore |
| `list` | Show all saved layouts |
| `show <name>` | Display layout details |
| `delete <name>` | Remove a layout |
| `help` | Show usage information |

## Layout Names

- Lowercase letters, numbers, hyphens, underscores
- Maximum 32 characters
- Examples: `coding`, `review`, `deep-work`, `meeting_standup`
- **Saving with an existing name overwrites the layout**

## File Locations

| Purpose | Path |
|---------|------|
| Fish function | `nix/home/mp/modules/fish/functions/a_mp/aerospace-layout.fish` |
| Layout storage | `~/.config/aerospace-layouts/*.json` |

## Layout File Format

Layouts are stored as JSON:

```json
{
  "schema_version": 1,
  "name": "coding",
  "created_at": "2025-01-15T10:00:00Z",
  "scope": "focused-monitor",
  "focused_workspace": "1",
  "windows": [
    {
      "app_bundle_id": "com.google.Chrome",
      "workspace": "B",
      "count": 2,
      "window_titles": ["GitHub - Mozilla Firefox", "Google Docs"]
    },
    {
      "app_bundle_id": "net.kovidgoyal.kitty",
      "workspace": "T",
      "count": 1,
      "window_titles": ["dev session"]
    }
  ]
}
```

## How Restore Works

1. **Workspace validation**: Verifies all workspaces in layout exist
2. **App detection**: Checks which apps from layout are currently running
3. **Missing app handling**: With `--launch`, starts missing apps via bundle ID
4. **Window matching**: Uses three-tier matching:
   - Tier 1: Exact title match
   - Tier 2: Substring match (case-insensitive)
   - Tier 3: Any window from that app (sorted for determinism)
5. **Move optimization**: Skips windows already in correct workspace
6. **Focus restoration**: Switches to the saved focused workspace

## Requirements

- **Fish shell**: Version 3.4.0+ (for `string escape --style=regex`)
- **jq**: JSON processor (included in Nix tier1 packages)
- **AeroSpace**: Window manager must be running

## Known Limitations

- **Single monitor**: Currently only works with focused monitor
- **Workspace routing only**: Saves app → workspace assignments, not tiling tree/splits
- **Title volatility**: Window titles change; matching is hint-based
- **No session persistence**: Apps must already be running (or use `--launch`)

## Troubleshooting

### "Workspace 'X' in layout does not exist"

The layout references a workspace that doesn't exist in your current AeroSpace config. Either:
- Add the workspace to aerospace.toml
- Delete and recreate the layout with current workspaces

### "App not running: com.example.App"

The app from the layout isn't running. Use `--launch` to start it:

```fish
aerospace-layout restore coding --launch
```

## Example Workflow

```fish
# Set up your preferred arrangement
# (manually move windows to desired workspaces)

# Save it
aerospace-layout save deep-work

# Later, restore it
aerospace-layout restore deep-work
```
