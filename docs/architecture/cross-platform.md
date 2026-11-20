# Cross-Platform Support

Which platforms the flake supports, where code for one platform belongs, and what continuous integration (CI) checks on Linux.

---

## Current Scope

| Platform | System | Status |
|----------|--------|--------|
| macOS (Apple Silicon) | `aarch64-darwin` | The only host in the flake (`m5-mbp`) |
| macOS (Intel) | `x86_64-darwin` | Not supported; needs its own host, and some packages (such as CLIProxyAPI) only fetch Apple Silicon or Linux archives |
| Linux | `x86_64-linux` | Package outputs only: CLIProxyAPI for Linux, and the Mac build of it unpacked on Linux. No Home Manager or NixOS configuration |

[`flake.nix`](../../flake.nix) defines the outputs.

---

## Platform Boundaries

| Location | Purpose | Platform |
|----------|---------|----------|
| `home/mp/common.nix` | Shared settings: user, state version, session variables | Shared |
| `home/mp/darwin.nix` | macOS entry point; imports every module | Darwin only |
| `hosts/<hostname>/` | Machine-specific settings, including nix-darwin modules | Per machine |
| `modules/<tool>/` | Home Manager modules, one per tool | Any platform, unless the tool is macOS-only |

[Overview](overview.md#wiring) shows how these connect. No module checks which platform it runs on, because `darwin.nix` is the only home entry point. Put macOS-only options in `darwin.nix`, a host file, or a macOS-only module.

Homebrew (under `/opt/homebrew`, declared in [`homebrew.nix`](../../hosts/m5-mbp/homebrew.nix)), launchd user services, and [AeroSpace](aerospace.md) exist only on macOS.

---

## Continuous Integration

[`.github/workflows/nix-check.yml`](../../.github/workflows/nix-check.yml) defines the CI job. It runs on Linux with import from derivation disabled, so evaluation never needs a macOS builder. It runs the shell tests in `tests/` and evaluates the Darwin system. Its `nix flake check --no-build --all-systems` step also evaluates the Linux package outputs without building them. CI doesn't build or activate macOS. Build it on the Mac with `nix-verify` ([command ladder](command-ladder.md)).
