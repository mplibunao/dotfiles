# Investigation: AeroSpace vs `yabai` for agent-friendly window management

## Summary
AeroSpace is the better current fit for MP's agent-first workflow. The workflow adjustment is to use a small number of visible accordion workspaces as agent cockpits instead of spreading agent-operated apps across many virtual workspaces.

The current declared setup is tiling-first because AeroSpace defaults new root containers to `tiles`, but live usage is already mixed. Workspace `6` is the Codex work area with Chrome available for inspection, while workspace `3` is a real RepoPrompt `h_accordion` group that Computer Use can inspect. The most productive workflow is to observe workspace `3` when RepoPrompt context matters, then return to workspace `6` for work.

Recommended operating model: keep two primary agent-facing workspaces, plus one optional scratch workspace. Use workspace `6` for work, workspace `3` or `4` for research/context, and `X` or `I` for temporary parallel work. Switching back to `yabai` doesn't pay off now because `yabai`'s native Spaces and stack layout are useful, but the SIP, scripting-addition, Nix migration, and maintenance costs outweigh the expected gain.

## Symptoms
- AeroSpace may reduce agent usefulness if its virtual workspaces hide app windows from Computer Use or force the agent and user into the same visible context.
- The current workflow may benefit from AeroSpace accordion layouts, `yabai`/macOS spaces, or a hybrid convention that keeps related agent-operated apps together.
- The long-term choice should account for agent friendliness, window visibility, speed, feature set, setup risk, SIP requirements, maintainability, and Dvorak-aware keybinding ergonomics.

## Verification Plan
- Inspect the declared dotfiles AeroSpace configuration and any legacy `yabai`/`skhd` configuration, then map the active workflow to tiling, accordion, floating, and workspace usage.
- Query live AeroSpace state with its CLI to enumerate workspaces, focused workspace, visible windows, layout types, and app placement.
- Compare local upstream sources for AeroSpace and `yabai` after refreshing both repositories, with attention to workspace model, focus model, stacking/accordion support, scripting surface, performance claims, and SIP-dependent features.
- Use Computer Use for a read-only screen/accessibility observation of the current Codex/Chrome workspace so the report distinguishes what the CLI proves from what the UI actually exposes to an agent.

## Background / Prior Research
- Local references were refreshed before investigation: `/Users/mp/references/window-manager/AeroSpace` was pulled with `git pull --ff-only`, and `/Users/mp/references/window-manager/yabai` was cloned from `https://github.com/koekeishiya/yabai.git`.
- RepoPrompt `personal-toolkit` workspace now includes `/Users/mp/Projects/personal/dotfiles`, `/Users/mp/references/window-manager/AeroSpace`, and `/Users/mp/references/window-manager/yabai`.
- Live AeroSpace state on 2026-07-01:
  - Active workspace: `6`.
  - Workspaces: `1`, `3`, `6`, `7`, `8`, `9`, `D`, `M`, `O`.
  - Current focused window: `Codex` on workspace `6`, root layout `h_tiles`.
  - Chrome is also on workspace `6`, floating within an `h_tiles` root layout.
  - RepoPrompt windows are on workspace `3` with `h_accordion` as the window, parent, and root layout.
  - One monitor is active: built-in Retina display.
- Computer Use observations:
  - Computer Use is blocked from inspecting the Codex app itself.
  - Computer Use can inspect the Chrome window in workspace `6`, including the local keyboard-stack page that documents AeroSpace bindings.
  - The Chrome accessibility tree shows the current AeroSpace bindings include `Alt+Backslash` for tile layout and `Alt+Comma` for accordion layout.
  - Switching to workspace `3` for observation confirmed that all three RepoPrompt windows are visible in a real `h_accordion` group: `Deco iOS Automation — wiki`, `Dispatch Copy Review — emm`, and `personal-toolkit`.
  - Computer Use can inspect the visible RepoPrompt app on workspace `3`, which supports a workflow where the agent temporarily monitors an AeroSpace accordion workspace and then returns to workspace `6`.
- AeroSpace upstream facts from `/Users/mp/references/window-manager/AeroSpace`:
  - AeroSpace has its own Spaces as virtual workspaces rather than using macOS Spaces, and inactive workspace windows move to a small offscreen/corner area. Evidence: `docs/guide.adoc:427-446`.
  - AeroSpace recommends one native macOS Space, or one macOS Space per monitor when separate display spaces are enabled. Evidence: `docs/guide.adoc:446-453`.
  - Accordion is an overlapping layout where windows are placed in the same container area with padding showing neighbors, rather than a macOS tab group. Evidence: `docs/guide.adoc:318-345`, `Sources/AppBundle/layout/layoutRecursive.swift:144-176`.
  - AeroSpace-hidden workspace windows remain real windows managed through Accessibility frame changes. Evidence: `Sources/AppBundle/layout/refresh.swift:190-200`, `Sources/AppBundle/tree/MacWindow.swift:123-152`, `Sources/AppBundle/tree/MacWindow.swift:190-192`.
  - AeroSpace exposes live state through `list-windows`, `list-workspaces`, `list-monitors`, `list-apps`, and event streams through `subscribe`. Evidence: `docs/aerospace-list-windows.adoc:9-108`, `docs/aerospace-list-workspaces.adoc:9-89`, `docs/aerospace-subscribe.adoc:9-68`.
- `yabai` upstream facts from `/Users/mp/references/window-manager/yabai`:
  - `yabai` controls native macOS Mission Control Spaces rather than creating a virtual workspace model. Evidence: `doc/yabai.asciidoc:108`, `src/space_manager.c:633-649`, `src/space.c:3-15`.
  - `yabai` supports `bsp`, `stack`, and `float` space layouts, and has window stack commands/selectors. Evidence: `doc/yabai.asciidoc:235-236`, `doc/yabai.asciidoc:354-355`, `doc/yabai.asciidoc:403-408`.
  - `yabai` has a strong JSON automation surface for displays, spaces, windows, rules, and signals. Evidence: `doc/yabai.asciidoc:467-493`, `doc/yabai.asciidoc:499-584`, `doc/yabai.asciidoc:726-883`.
  - `yabai`'s SIP requirements are feature-specific. Current docs still require partial SIP disable for scripting addition load/uninstall and many privileged space/window operations, but recent changelog entries moved some operations back to SIP-enabled paths. Evidence: `doc/yabai.asciidoc:35-44`, `doc/yabai.asciidoc:276-329`, `CHANGELOG.md:12-14`, `CHANGELOG.md:41-44`.
  - Current `yabai` removed built-in window borders in v6.0.0; border workflows now imply an external border tool such as JankyBorders rather than `yabai`'s own border feature. Evidence: `CHANGELOG.md:315-330`.

## Investigator Findings

### Verified ownership and current posture

The current window-manager owner is AeroSpace through the Nix-managed path, not the legacy `yabai`/`skhd` files. The dotfiles router says non-`nix/` configuration is legacy during the Nix migration (`/Users/mp/Projects/personal/dotfiles/AGENTS.md:3-8`), and the Home Manager user configuration imports the AeroSpace module at `/Users/mp/Projects/personal/dotfiles/nix/home/mp/darwin.nix:20-23`. The AeroSpace TOML states the active ownership split: TOML owns keybindings, key mapping, gaps, layout, normalization, and startup commands; Nix owns float rules and environment values; Home Manager owns login lifecycle (`/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/aerospace/aerospace.toml:1-10`). ADR-014 says the same thing as an accepted decision: TOML is the canonical authored configuration, and Nix adds only values that depend on Home Manager (`/Users/mp/Projects/personal/dotfiles/nix/docs/decisions/014-aerospace-toml-as-canonical-authored-config.md:17-27`). The module parses `aerospace.toml` and `nix/data/workspaces.toml`. It also checks that Nix-owned keys stay out of TOML (`/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/aerospace/default.nix:20-55`).

The declared setup is tiling-first. The canonical TOML sets `default-root-container-layout = 'tiles'`, with accordion available as a command rather than as the default (`/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/aerospace/aerospace.toml:32-35`, `/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/aerospace/aerospace.toml:71-83`). The active keybinding registry keeps AeroSpace on and turns the legacy `skhd` source off (`/Users/mp/Projects/personal/dotfiles/keybinds/manifest.toml:20-30`). The recorded live state is mixed, not pure tiling: workspace `6` had Codex focused in `h_tiles` with Chrome floating, while workspace `3` had RepoPrompt windows in `h_accordion` (`/Users/mp/Projects/personal/dotfiles/nix/docs/investigations/aerospace-yabai-agent-friendliness-2026-07-01.md:20-35`).

Workspace ownership supports a small number of stable roles. `nix/data/workspaces.toml` defines terminal `1`, browser `3`, RepoPrompt `4`, Codex `6`, Slack `S`, Discord `D`, music `M`, mixed scratch `X`, and internal scratch `I` (`/Users/mp/Projects/personal/dotfiles/nix/data/workspaces.toml:1-21`). The Nix overlay maps startup apps to those registry names, including browsers to `3`, RepoPrompt to `4`, Codex to `6`, Slack to `S`, and Discord to `D` (`/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/aerospace/default.nix:89-159`). Those assignment rules are startup-only, so new windows can still be placed manually during a session (`/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/aerospace/default.nix:85-88`, `/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/aerospace/default.nix:161-168`). That makes the active posture: tiling-first by default, mixed in practice, and suitable for a deliberate accordion-first convention on selected workspaces.

### Computer Use workflow: Monitor workspace `3`, return to workspace `6`

Using workspace `3` as an accordion monitoring cockpit and then returning to workspace `6` is better supported by the evidence than moving windows between workspaces during agent operation. The report already records the key observation: Computer Use can inspect visible RepoPrompt windows on workspace `3`. That observation supports a workflow where the agent temporarily monitors the accordion workspace before returning to workspace `6` (`/Users/mp/Projects/personal/dotfiles/nix/docs/investigations/aerospace-yabai-agent-friendliness-2026-07-01.md:30-35`). Moving windows is less attractive because the current AeroSpace layout manager saves app-to-workspace routing only, not exact tile trees, split ratios, or accordion state (`/Users/mp/Projects/personal/dotfiles/nix/docs/aerospace-layouts.md:3-4`, `/Users/mp/Projects/personal/dotfiles/nix/docs/aerospace-layouts.md:105-108`). The fish function confirms the saved layout comes from current windows grouped by app bundle ID, workspace, count, and titles, rather than from a full visual tree (`/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/fish/functions/a_mp/aerospace-layout.fish:95-126`).

The upstream AeroSpace model explains why workspace switching is the right mitigation. AeroSpace accordion places windows on top of each other with directional padding and focus navigation (`/Users/mp/references/window-manager/AeroSpace/docs/guide.adoc:327-351`), while AeroSpace virtual workspaces aren't native macOS Spaces and AeroSpace hides inactive workspace windows offscreen or in corners (`/Users/mp/references/window-manager/AeroSpace/docs/guide.adoc:427-446`, `/Users/mp/references/window-manager/AeroSpace/Sources/AppBundle/layout/refresh.swift:190-200`, `/Users/mp/references/window-manager/AeroSpace/Sources/AppBundle/tree/MacWindow.swift:123-152`). The local macOS defaults already mitigate AeroSpace’s Mission Control preview issue by enabling grouped application previews (`/Users/mp/Projects/personal/dotfiles/nix/hosts/m5-mbp/defaults.nix:49-51`). A visible accordion cockpit avoids the offscreen-window visibility gap without changing the stable role assignments that make the setup predictable.

### Legacy window-manager comparison

`yabai` is agent-friendly enough to remain a credible fallback, but the evidence doesn't justify switching back by default. `yabai` has clear strengths: it controls native macOS Spaces through Space API calls (`/Users/mp/references/window-manager/yabai/src/space_manager.c:491-548`, `/Users/mp/references/window-manager/yabai/src/space.c:3-15`), it supports `bsp`, `stack`, and `float` layouts (`/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:232-235`, `/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:354-355`), and it exposes JSON queries for displays, spaces, and windows (`/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:461-588`). Its signal API is also strong for automation (`/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:724-743`). The old dotfiles used those primitives: `yabairc` configured BSP layout, opacity, gaps, focus/mouse behavior, limelight, and borders (`/Users/mp/Projects/personal/dotfiles/yabai/yabairc:69-88`, `/Users/mp/Projects/personal/dotfiles/yabai/yabairc:120-131`, `/Users/mp/Projects/personal/dotfiles/yabai/yabairc:162-168`), while `skhdrc` had stack navigation and stack creation bindings (`/Users/mp/Projects/personal/dotfiles/yabai/skhdrc:159-183`). The old layout scripts could save absolute window positions and target spaces (`/Users/mp/Projects/personal/dotfiles/custom-scripts/layouts/save_layout.sh:30-31`, `/Users/mp/Projects/personal/dotfiles/custom-scripts/layouts/restore_layout.sh:24-31`).

The downside is still material. The accepted AeroSpace ADR chose AeroSpace for no SIP disable, simpler TOML management, enough features, active development, and a good Nix fit (`/Users/mp/Projects/personal/dotfiles/nix/docs/decisions/006-aerospace-instead-of-yabai.md:10-20`). `yabai`’s official docs still mark scripting-addition load/uninstall, window opacity/shadow/animation, many space operations, and several rule/window properties as requiring partial SIP disable (`/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:35-44`, `/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:178-207`, `/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:276-329`, `/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:426-459`, `/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:609-696`). Recent `yabai` changelog entries improve SIP-enabled behavior for some operations, including moving windows between spaces and focusing spaces (`/Users/mp/references/window-manager/yabai/CHANGELOG.md:12-14`, `/Users/mp/references/window-manager/yabai/CHANGELOG.md:41-44`), but the same changelog also shows ongoing scripting-addition compatibility churn (`/Users/mp/references/window-manager/yabai/CHANGELOG.md:18-23`, `/Users/mp/references/window-manager/yabai/CHANGELOG.md:48-53`). `yabai` also has its own agent-visibility caveat: some window properties need a valid AX reference, and `yabai` can retrieve that reference only when the window’s Space is active. A startup workaround covers inactive Spaces (`/Users/mp/references/window-manager/yabai/doc/yabai.asciidoc:499-588`). Native Spaces help, but they don't remove inactive-context limitations.

### Recommended number of active agent-facing workspaces

Use two primary agent-facing workspaces, with one optional scratch workspace. The evidence supports an execution cockpit and a context cockpit: workspace `6` is already the Codex execution area, while workspace `3` has visible RepoPrompt windows in an accordion monitoring area in the live observation (`/Users/mp/Projects/personal/dotfiles/nix/docs/investigations/aerospace-yabai-agent-friendliness-2026-07-01.md:20-35`). MP’s parallel work justifies a third scratch workspace because the registry already reserves `X` for mixed layouts and `I` for internal-display scratch (`/Users/mp/Projects/personal/dotfiles/nix/data/workspaces.toml:19-20`). The current evidence doesn't justify more than three active agent-facing workspaces because AeroSpace’s inactive-workspace hiding is the core Computer Use constraint, and scattering agent context across many virtual workspaces would recreate the visibility gap that the accordion cockpit avoids.

### Drift and generated-doc risks

Two docs appear stale against current configuration, so they shouldn't serve as canonical evidence. `keybinds/generated/INVENTORY_AI.md` still lists lettered `B/T/C/M` examples that don't match the current workspace registry and TOML lettered set (`/Users/mp/Projects/personal/dotfiles/keybinds/generated/INVENTORY_AI.md:60-69`, `/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/aerospace/aerospace.toml:113-140`, `/Users/mp/Projects/personal/dotfiles/nix/data/workspaces.toml:10-20`). `nix/docs/aerospace-cheatsheet.md` says browsers go to `B`, terminals to `T`, and chat apps to `C`, while the active Nix overlay maps browsers to `3`, terminals to `1`, Slack to `S`, Discord to `D`, RepoPrompt to `4`, and Codex to `6` (`/Users/mp/Projects/personal/dotfiles/nix/docs/aerospace-cheatsheet.md:74-85`, `/Users/mp/Projects/personal/dotfiles/nix/home/mp/modules/aerospace/default.nix:89-159`). This investigation records the drift risk only; the source docs remain unchanged.

### Concise conclusion

MP should stay on AeroSpace and add an accordion-first agent cockpit convention. The current configuration defaults to tiles, but live use already mixes tiles and accordion. Workspace `3` accordion monitoring plus returning to workspace `6` is a better Computer Use workflow than moving windows because it preserves stable workspace roles. That workflow also avoids layout restoration, which can't recreate full visual state. `yabai`’s native Spaces and stack layout are stronger primitives on paper, but they don't justify the SIP, scripting-addition, Nix migration, and maintenance costs unless the two-workspace accordion cockpit still leaves AeroSpace’s virtual workspace hiding as a proven blocker.

## Investigation Log
- Read the dotfiles and Nix agent instructions before treating any window-manager file as canonical.
- Refreshed upstream references: pulled AeroSpace and cloned `yabai` under `/Users/mp/references/window-manager/`.
- Added `dotfiles`, `AeroSpace`, and `yabai` to the RepoPrompt `personal-toolkit` workspace for a multi-root investigation.
- Queried live AeroSpace state with the CLI and confirmed workspace `6` as the work area and workspace `3` as a RepoPrompt accordion group.
- Used Computer Use to verify that Chrome on workspace `6` and RepoPrompt on workspace `3` are available for inspection, while Codex itself is blocked from Computer Use inspection.
- Ran RepoPrompt external explore agents for AeroSpace and `yabai` upstream behavior.
- Ran RepoPrompt `context_builder` and a pair investigator to cross-check current configuration ownership, live posture, `yabai` fallback value, and stale-doc risks.

## Root Cause
The concern comes from AeroSpace's workspace model. AeroSpace workspaces are virtual; AeroSpace moves inactive workspace windows into offscreen or corner positions rather than representing them as native macOS Mission Control Spaces. That model is fast and low-friction for keyboard-driven human work, but it can fragment what Computer Use can inspect if an agent needs many apps across many AeroSpace workspaces.

The current dotfiles setup already has the right mitigation available. Accordion layout keeps related windows visible inside one AeroSpace workspace, and workspace `3` proves that pattern works for RepoPrompt. The issue is workflow shape, not a missing window-manager capability.

## Recommendations
1. Stay on AeroSpace as the primary window manager.
2. Adopt an accordion-first convention for agent-facing context work.
3. Use two primary agent-facing workspaces: workspace `6` for active work, and workspace `3` or `4` for research/context.
4. Keep one optional scratch workspace, preferably `X` or `I`, for MP's parallel work or temporary mixed tasks.
5. Prefer switching to the relevant accordion workspace and returning afterward over moving windows between workspaces during agent operation.
6. Treat `yabai` as a fallback only if the two-workspace accordion workflow still leaves AeroSpace's virtual workspace hiding as a proven blocker.
7. Refresh stale generated keybinding and AeroSpace cheat-sheet docs before using those docs as automation evidence.

## Preventive Measures
- Keep `nix/home/mp/modules/aerospace/aerospace.toml` as the canonical authored AeroSpace configuration.
- Keep `nix/home/mp/modules/aerospace/default.nix` as the owner of Nix-managed overlays such as app assignments, float rules, environment values, and `launchd` lifecycle.
- Treat generated keybinding inventories as snapshots, not source of truth.
- Re-run keybinding inventory/conflict generation after AeroSpace binding changes.
- Document the adopted agent cockpit convention in the AeroSpace docs if MP decides to keep using it.
- Revisit `yabai` only with a separate migration plan covering SIP posture, scripting addition ownership, `skhd` or replacement bindings, Nix integration, and macOS-update maintenance.
