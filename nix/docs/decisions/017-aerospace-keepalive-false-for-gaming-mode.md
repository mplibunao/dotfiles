# ADR-017: AeroSpace KeepAlive=false for gaming mode

**Status:** accepted
**Date:** 2026-01-02

## Context

User wants to quit AeroSpace during gaming sessions without it auto-restarting. With `launchd.keepAlive = true` (the default), launchd respawns AeroSpace immediately when killed or quit. Using Home Manager `programs.aerospace` module (not nix-darwin `services.aerospace`).

## Decision

Set `programs.aerospace.launchd.keepAlive = false` while keeping `launchd.enable = true`.

Additionally, override the HM aerospace module's `onChange` hook to tolerate AeroSpace not running. The default hook runs `aerospace reload-config` unconditionally, which fails if the process isn't running.

Reasons:

1. Simplest solution: one-line config change.
2. Preserves `RunAtLoad=true` (starts at login).
3. Preserves config auto-reload when running.
4. Avoids Login Items path stability issues with Nix store paths.
5. User can quit AeroSpace anytime for gaming; restart via `launchctl kickstart`.

### Implementation

```nix
# Keep launchd for auto-start and config reload
programs.aerospace.launchd.enable = true;
programs.aerospace.launchd.keepAlive = false;  # No respawn after quit

# Override onChange to be non-fatal when AeroSpace is stopped
# Path uses leading slash due to how HM resolves xdg paths internally
home.file."/.config/aerospace/aerospace.toml".onChange = lib.mkForce ''
  if /usr/bin/pgrep -x "AeroSpace" >/dev/null 2>&1; then
    echo "Reloading AeroSpace config..." >&2
    ${pkgs.coreutils}/bin/timeout 5s ${lib.getExe config.programs.aerospace.package} reload-config || true
  fi
'';
```

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Disable launchd entirely | Full control | Loses config auto-reload, requires Login Items with path stability issues |
| `launchctl bootout` for gaming | Works | More complex than just quitting the app |
| Conditional KeepAlive dict | Crash recovery only | HM option is boolean-only; implementing dict requires bypassing `programs.aerospace.launchd` |
| Set `keepAlive = false` (chosen) | Simple, one-line change | No auto-recovery after crashes |

## Consequences

- AeroSpace starts automatically at login (`RunAtLoad=true` preserved).
- Quitting/killing AeroSpace stops it until manual restart or next login.
- Crashes don't auto-recover; user must restart manually.
- Config changes apply on next start if AeroSpace is stopped during rebuild.
- Operational commands documented in `docs/aerospace-cheatsheet.md`.

## Migration

Edit applied to `aerospace/default.nix`; verified with `darwin-rebuild build`.

## Risks

If crash resilience becomes important, set `keepAlive = true` and remove the `onChange` override.
