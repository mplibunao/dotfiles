# Codex Skill Sync (copy-based)

Codex CLI does not reliably discover skills when `~/.codex/skills/<skill>` is a symlink. This setup copies skill directories into `~/.codex/skills/` as real directories.

The result is a flat structure:

```text
~/.codex/skills/
  .system/        # Codex built-in skills (never touched)
  beads/          # copied from claude-toolkit/skills/beads
  flow-plan/      # copied from ~/.claude/plugins/.../flow/skills/flow-plan
  rp-explorer/    # copied from ~/.claude/plugins/.../flow/skills/rp-explorer
  ...             # one real directory per skill
```

## Why copies instead of symlinks?

Some Codex CLI builds do not reliably discover skills when the skill directory is a symlink. Copying as real directories ensures skills work everywhere.

The tradeoff is that copies don't auto-update when the source changes. To sync updates:
- Run `bun run ~/.claude/scripts/codex-sync-skills.ts --apply`

## How it works

Skill sync is handled by the standalone script `codex-sync-skills.ts` (in the claude-toolkit repo). The script:

1. Discovers skills from source directories (toolkit skills + plugin skills via `installed_plugins.json`)
2. Validates SKILL.md frontmatter for each skill
3. Copies skill directories into `~/.codex/skills/` via rsync
4. Never touches `~/.codex/skills/.system/` (Codex built-ins)
5. Uses `name:` in SKILL.md frontmatter (not the directory name) as the installed skill identity

### Constraints (enforced)

- `.system` is reserved (Codex built-ins live there)
- Skill names must match `^[A-Za-z0-9][A-Za-z0-9_-]*$`

### Skill identity (frontmatter contract)

Skill identity comes from the `name:` field in the SKILL.md frontmatter block.
The contract is strict to match the sync script:

- SKILL.md must start with frontmatter on the first line (`---`), optionally after a UTF-8 BOM.
- Only the first frontmatter block is parsed.
- `name:` must appear inside that block (quoted or unquoted).

If frontmatter is missing/invalid, the skill is refused with a warning.

### Managed marker file

Each installed skill directory includes a marker file used by the sync script to recognize managed skills:

```json
{
  "schema_version": 1,
  "managed_by": "claude-toolkit.codex-skill-sync",
  "skill_name": "beads",
  "installed_from": "/Users/mp/Projects/personal/ai/claude-toolkit/skills/beads",
  "installed_at": "2026-01-04T22:13:59Z",
  "installer": "codex-sync-skills"
}
```

The sync script will refuse to overwrite unmanaged directories unless forced.

## Running the sync

```bash
# Dry-run (see what would change)
bun run ~/.claude/scripts/codex-sync-skills.ts

# Apply changes
bun run ~/.claude/scripts/codex-sync-skills.ts --apply
```

See `claude-toolkit/docs/workflows/codex-skill-sync.md` for full documentation.

## Verifying it worked

```bash
# Check skills are real directories (not symlinks)
ls -la ~/.codex/skills

# Verify a skill is not a symlink
test -L ~/.codex/skills/beads && echo "symlink (bad)" || echo "real dir (good)"

# Start a new Codex session to test
codex exec "List the skills you have access to"
```

## Collision audit

Skill identity comes from `name:` in SKILL.md. This command finds duplicates:

```bash
find ~/.codex/skills -name SKILL.md -print0 | xargs -0 python3 - <<'PY'
import sys

def parse_name(path):
    try:
        data = open(path, 'rb').read()
    except OSError:
        return None
    if data.startswith(b"\xef\xbb\xbf"):
        data = data[3:]
    lines = data.decode('utf-8', errors='replace').splitlines()
    if not lines or lines[0].strip() != '---':
        return None
    for line in lines[1:]:
        if line.strip() == '---':
            break
        if line.strip().startswith('name:'):
            value = line.split(':', 1)[1].strip()
            if value.startswith(('\"', "'")) and value.endswith(('\"', "'")) and len(value) >= 2:
                value = value[1:-1]
            else:
                if ' #' in value:
                    value = value.split(' #', 1)[0]
                if '\t#' in value:
                    value = value.split('\t#', 1)[0]
            return value.strip() or None
    return None

names = []
for path in sys.stdin.read().split('\0'):
    if not path:
        continue
    name = parse_name(path)
    if name:
        names.append(name)

for name in sorted(set(n for n in names if names.count(n) > 1)):
    print(name)
PY
```

Empty output means no collisions.

## Removal / cleanup

The script does **not** auto-prune removed or renamed skills by default.
Use `--prune` to remove skills no longer in any source directory, or clean up manually:

```bash
find ~/.codex/skills -maxdepth 2 -name .codex-sync-managed.json -print0 | xargs -0 -n1 dirname
```
