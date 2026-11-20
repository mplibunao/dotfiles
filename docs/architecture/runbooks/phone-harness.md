# Phone Harness: uv installation and recovery

Ownership decision: [ADR-024](../../decisions/024-phone-harness-installation-ownership.md). Nix supplies uv; uv manages Phone Harness outside Nix generations. The installed command is a Python application, not an MCP server. It requires no Codex MCP configuration or restart.

## Tested macOS baseline

| Component | Version |
| --- | --- |
| Phone Harness | 0.3.3 |
| uv-managed Python | 3.13.14 |
| pyobjc-core | 12.2.2 |
| pyobjc-framework-Cocoa | 12.2.2 |
| pyobjc-framework-Quartz | 12.2.2 |
| pyobjc-framework-ApplicationServices | 12.2.2 |
| pyobjc-framework-CoreText | 12.2.2 |
| pyobjc-framework-CoreML | 12.2.2 |
| pyobjc-framework-Vision | 12.2.2 |

Resolution cutoff: November 3, 2026. Verified October 5, 2026 on 0.3.0: readable screenshots, opening App Store, returning Home, Home Screen paging in both directions, and vertical App Store scrolling.

Verified November 3, 2026 on 0.3.3, upgraded in place with the same pinned PyObjC versions and Python: screenshots, OCR, taps, scrolling, navigating Settings, and text entry into a focused field. Text entry works only with the keyboard-layout workaround in the `phone-assistance` skill, because this Mac runs Dvorak and the harness sends raw keycodes. Android through Phone Harness remains untested.

The PyObjC packages are Python adapters for Apple's macOS frameworks. They are present with either installation method; using uv avoids maintaining missing Nix package recipes for them.

## Ownership and configuration

- Executable: `~/.local/bin/phone-harness`.
- Environment and receipt: `~/.local/share/uv/tools/phone-harness/` and `uv-receipt.toml` within it.
- Mutable local configuration: `~/.config/phone-harness/config.json`. Keep it out of Git and the Nix store; preserve unrelated fields.
- Existing configuration has `telemetry: false`. Also use `PHONE_HARNESS_TELEMETRY=0` for agent launches; no new Nix environment declaration was selected.
- Existing Android adb path: `~/Library/Android/sdk/platform-tools/adb`. Do not introduce another ADB installation or server merely to use Phone Harness.

The iPhone route requires macOS, a paired iPhone Mirroring session, and the relevant Accessibility/Screen Recording permissions. It does not work from a Linux VPS. The separate upstream Android/ADB route can target Linux; assess it independently when needed. A hosted-phone subscription is not required for local-device use.

## Inspection without phone input

```sh
command -v phone-harness
ls -l "$HOME/.local/bin/phone-harness"
uv tool list
PHONE_HARNESS_TELEMETRY=0 phone-harness --help
```

Inspect the uv receipt before changing the environment. Help is the initial passive check; do not use `--doctor`, screenshots, or navigation as unattended package checks because they may inspect or interact with a device.

## Fresh installation or recovery

The current installation is already working; do not reinstall to match this documentation. For an authorized fresh macOS installation or recovery, the recorded runtime baseline can be requested with:

```sh
uv tool install --python 3.13.14 --exclude-newer 2026-11-03 \
  --with pyobjc-core==12.2.2 \
  --with pyobjc-framework-Cocoa==12.2.2 \
  --with pyobjc-framework-Quartz==12.2.2 \
  --with pyobjc-framework-ApplicationServices==12.2.2 \
  --with pyobjc-framework-CoreText==12.2.2 \
  --with pyobjc-framework-CoreML==12.2.2 \
  --with pyobjc-framework-Vision==12.2.2 \
  phone-harness==0.3.3
```

These explicit dependency constraints document the observed environment. The command above was exercised on November 3, 2026, both into a throwaway `UV_TOOL_DIR` and, with `--force`, over the working environment during the 0.3.0 to 0.3.3 upgrade. It does not provide artifact hashes or guarantee byte-identical reconstruction. The original installation receipt pins the application and cutoff, not every transitive dependency. Do not apply the macOS-specific PyObjC constraints to a Linux installation.

For a fresh configuration, the upstream interface supports disabling telemetry:

```sh
PHONE_HARNESS_TELEMETRY=0 phone-harness config set telemetry false
```

Keep the existing configuration when recovering. The human handles pairing, permission dialogs, and secrets. A changed Python executable may require macOS permissions to be granted again; do not reset existing permissions automatically.

## Updates and rollback

Choose explicit application, interpreter, and dependency versions; avoid an unconstrained `uv tool upgrade`. Record the existing receipt and installed versions, then validate a candidate in an isolated temporary environment before replacing the working one. Check help/imports without phone input first. Real-device smoke tests require an appropriate authorized session and visual verification.

Use uv's own uninstall/reinstall operations when replacement is actually needed. Check command resolution so an older executable does not shadow the intended one. Nix generation rollback restores Nix-managed packages, including uv, but does not restore this external application environment, its mutable configuration, permissions, pairing, or Android SDK. Recover Phone Harness using the recorded uv baseline instead.
