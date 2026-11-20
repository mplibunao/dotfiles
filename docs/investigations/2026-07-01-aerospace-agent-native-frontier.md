# Investigation: AI agents driving tiling window managers — state of the art and proposals for AeroSpace

**Method note:** unlike the sibling investigation (`2026-07-01-aerospace-yabai-agent-friendliness.md`), this is an external-research pass (deep-research: web search → fetch → 3-vote adversarial verification → synthesis), not live local verification. Claims below carry confidence tags from that verification process, not file:line evidence from this repo.

## 1. Executive summary

There is no publicly documented project where an AI agent drives a tiling window manager *alongside* Computer Use in a "stage-then-inspect" loop — the specific hybrid model this research asked about does not yet exist as prior art. What does exist, and is real rather than theoretical, is the surrounding infrastructure the hybrid model would be built from: (1) mature Computer-Use tooling (Anthropic's own tool, cua) that perceives the world exclusively through screenshots of the currently-visible display and is explicitly designed to run in an isolated, consistent environment rather than a user's live desktop; (2) a fast-growing ecosystem of macOS desktop-control MCP servers (MacOS-MCP, macos-automator-mcp, applescript-mcp) that give agents programmatic, non-visual control via the Accessibility API or AppleScript/JXA — none of which have any concept of a window manager, tiling, or Spaces; (3) one genuinely novel primitive, Cua's `cua-driver`, which lets an agent click/type/verify on real macOS apps in the background without stealing the cursor, focus, or Space — solving a *different* half of the problem than staging does; and (4) AeroSpace itself, which already ships the exact CLI primitives (JSON state queries, ID-targeted window moves, a live event stream) an agent needs to be the "hands" in a hybrid loop, but which nobody has yet wired to a vision agent. The opportunity is therefore not to find and adopt an existing agent-native tiling WM — none exists — but to build the missing middle layer on top of AeroSpace's already-agent-friendly CLI, informed by patterns from the adjacent tools that do exist.

## 2. State of the art

### 2.1 Visual (Computer-Use) agents see only the current screenshot — by design

Anthropic's own computer-use tool documentation is unambiguous about the single perception channel available to a visual agent: "Screenshot capture: See what's currently displayed on screen" — full stop, no other sensing modality [confidence: high; platform.claude.com/docs/en/agents-and-tools/tool-use/computer-use-tool]. There is no accessibility-tree read, no window enumeration, no DOM access built into the tool itself; every fact the agent has about the world arrives as a bitmap of the current display, refreshed only when the agent issues a new screenshot action. Actions like scroll or zoom don't circumvent this — they first change what's rendered, then a fresh screenshot captures the result, which reinforces rather than contradicts the constraint.

Consistent with a screenshot-only sensorium, Anthropic recommends running the tool in a dedicated, isolated environment with a deliberately consistent graphical interface rather than a user's live desktop: the reference implementation runs Xvfb (a virtual X11 display), Mutter (window manager) and Tint2 (panel) inside a Docker container, explicitly for "a consistent graphical interface for Claude to interact with" and to prevent "direct system attacks or accidents" [confidence: high; same source]. This is a strong signal about how Anthropic itself thinks about the problem: rather than asking the vision agent to cope with an unpredictable desktop, they hold the desktop's layout constant and known in advance. That is architecturally close to what tiling does for a human, except Anthropic achieves it by *replacing* the desktop with a disposable one rather than *taming* the user's real one.

The same docs candidly flag two operational limits relevant to any agent-plus-WM design: reliability "might be lower when interacting with niche applications or multiple applications at once," and latency is high enough that computer use is "best suited" to non-time-critical tasks like background information gathering and automated testing rather than fast interactive work [confidence: high; same source]. Both point toward using vision sparingly and deterministically — call it once, on a known-good layout, rather than looping it against a shifting multi-app scene.

### 2.2 Programmatic/non-visual macOS control is a real, active ecosystem — but stops at the app, not the window manager

Three independent MCP servers demonstrate that "agent drives macOS programmatically" is now a commodity capability, each occupying a different rung of the same ladder:

- **macos-automator-mcp** (steipete) exposes a single generic `execute_script` tool that runs arbitrary AppleScript or JXA — inline, from a file, or from a ~200-recipe knowledge base — covering app activation and System Events UI automation (clicks, keystrokes) [confidence: high; github.com/steipete/macos-automator-mcp]. It is over a year old, MIT-licensed, 839 stars, still being pushed to as of today — a genuinely mature, general-purpose automation substrate, not a toy.
- **MacOS-MCP** (CursorTouch) is younger but shipping fast (v0.3.8, 9 releases between March and June 2026, ~100 stars) and takes the accessibility-tree route instead of AppleScript: it reads the macOS Accessibility API (AXUIElement tree) as structured data — "doesn't require computer vision, fine-tuned models, or specialized setup" — and its own recommended workflow is explicitly accessibility-first, vision-as-fallback: call a snapshot tool, act on the returned element coordinates, and "use screenshots/vision only when Accessibility data is missing or ambiguous" [confidence: high; github.com/CursorTouch/MacOS-MCP]. This is the clearest concrete example in the survey of the "programmatic alternative to screenshot-based Computer Use," and it is fast (~50ms per read, reportedly 40-100x faster than a screenshot round-trip).
- **applescript-mcp** (joshrutkowski) is narrower and instructive precisely because of what it omits: its tool surface is System (volume, `get_frontmost_app`, `launch_app`, `quit_app`, dark-mode toggle), plus Calendar/Clipboard/Finder/Notifications/iTerm/Mail/Messages/Notes/Pages helpers — app-level and system-level control only. Two independent fetches of the README confirm there is no window-management, workspace, Space, or Mission Control tool anywhere in the project [confidence: high; github.com/joshrutkowski/applescript-mcp].

The pattern across all three, corroborated by a fourth data point (`wmux`, below), is consistent and important: **every generalist macOS-agent tool that exists today stops at "which app is frontmost" or "click this UI element." None of them has a concept of a window manager, a workspace, tiling, or a Space.** This is a real, evidenced gap, not a hunch — three separately-authored projects converge on the same boundary independently. An AeroSpace-aware layer sits in genuinely open territory.

### 2.3 The one real innovation: acting on the desktop *without* disturbing the human's focus

The most significant piece of prior art for the hybrid-model question is Cua's `cua-driver`, an open-source macOS driver (MIT, part of the 19.3k-star `trycua/cua` project) that lets an agent "click, type, and verify" on real Mac applications in the background — explicitly: "the cursor doesn't move. Focus doesn't change. macOS doesn't follow the agent across Spaces" [confidence: high; cua.ai/blog/inside-macos-window-internals, github.com/trycua/cua]. Mechanically, it works by calling the private SkyLight framework's `SLEventPostToPid`, which posts synthesized input events directly to one target process without going through the shared HID event tap that a real mouse/keyboard would use — i.e., it is architecturally incapable of moving the visible cursor because it never touches the global input stream at all [confidence: high; corroborated by an independent private-framework survey cataloguing the same SkyLight symbols]. This is the same "focus-without-raise" trick yabai uses internally, repurposed as an agent primitive. A Hacker News discussion of the launch drew no functional disputes — the only criticism was of opt-out telemetry, not of whether it works [HN item 47936312].

This matters because it demonstrates a *second, independent way* to solve "the agent can't see/act on a hidden workspace" that has nothing to do with staging: instead of bringing a hidden window into view, cua-driver lets the agent act on it *while it stays hidden*, using the accessibility tree for verification rather than a screenshot [confidence: medium — this framing is Cua's own, not independently confirmed]. It has real limits: canvas/gaming apps and some Chromium synthetic-click paths still require real foreground activation.

### 2.4 Terminal-level prior art: agent-native pane management exists, one level down from a WM

`wmux` — a real, actively-shipping (v3.11.1, June 29 2026), MIT-licensed, TypeScript Windows terminal — runs Claude Code, Codex CLI, and Gemini CLI in split panes and auto-registers a zero-config MCP server exposing `terminal_read`/`terminal_send` plus `workspace_list`/`surface_list`/`pane_list` enumeration tools the moment an agent launches [confidence: high; github.com/openwong2kim/wmux]. It's Windows-only and a terminal multiplexer, not an OS-level tiling WM, but two design cues transfer directly: zero-config MCP auto-registration on agent launch is workable, and enumeration (`list`) primitives are treated as a baseline requirement for making a layout surface agent-addressable. Its README says it was "inspired by" `cmux`, a pre-existing macOS tmux-based agent multiplexer — a closer macOS analog worth a follow-up look.

### 2.5 Cua's broader infrastructure: mature, but with no window-manager concept either

`trycua/cua` — "open-source infrastructure for Computer-Use Agents. Sandboxes, SDKs, and benchmarks" — is real and substantial (19.3k GitHub stars, MIT, YC-backed, actively pushed), independently corroborated as genuine shipping infrastructure with honest limits: Apple-Silicon-only macOS support, ~50GB VM images, OSWorld benchmark accuracy still only 30-50% [confidence: medium on scale specifics — survived verification at 2-1]. Critically, and checked directly rather than assumed: **cua contains no explicit support or mention of window managers, tiling, macOS Spaces, or staging windows into view for an agent** — this absence survived adversarial verification 0-3 (all three votes independently confirmed the absence is real). Even the most mature, best-funded Computer-Use infra project surveyed does not treat window-manager staging as a first-class primitive — the cleanest evidence that CLI-driven WM staging is a genuine, unclaimed gap.

### 2.6 AeroSpace's own primitives: closer to agent-ready than it looks

- **Virtual (not native) workspaces confirmed as the mechanism behind the visibility gap.** AeroSpace's README: it "employs its own emulation of virtual workspaces instead of relying on native macOS Spaces due to their considerable limitations," and inactive-workspace windows are placed outside the visible area of the screen until switched back [confidence: high; github.com/nikitabobko/AeroSpace, nikitabobko.github.io/AeroSpace/guide]. A screenshot-only Computer-Use agent categorically cannot see them without an actual workspace switch.
- **Never requires disabling SIP** — relies solely on the public Accessibility API, unlike yabai's Dock.app scripting-addition injection [confidence: high].
- **Machine-readable state is already there.** `list-windows`/`list-workspaces`/`list-monitors` all support `--json`; verified both from docs and live execution on this machine. Notably, **no frame/geometry field exists at all** in the JSON field enum — confirmed against the AeroSpace source (`ListWindowsCmdArgs.swift`), not just docs — this is a hard gap relative to yabai, not a documentation omission.
- **Windows can be targeted by ID, not just focus.** `move-node-to-workspace --window-id <id>` acts on a specified window; precedence order in source: `--window-id` flag > `--workspace` flag > `AEROSPACE_WINDOW_ID` env > `AEROSPACE_WORKSPACE` env > real focus [confidence: high; confirmed against `cmdResolveTargetOrReportError.swift`].
- **A live event stream exists.** `aerospace subscribe` emits JSON Lines for `focus-changed`, `focused-monitor-changed`, `focused-workspace-changed`, `mode-changed`, `window-detected`, `binding-triggered`. On connect, initial snapshot events are sent for everything except `window-detected`/`binding-triggered`, and that initial burst is **not ordering-guaranteed** (Set-backed iteration in `subscriptions.swift`) — a caller must match on event content, not assume order, and must distinguish the initial snapshot burst from live events.

## 3. Patterns and failure modes observed

1. **Every mature tool commits to one perception channel** — none mix screenshot vision with accessibility-tree reads as co-equal, continuously-available signals. Treat CLI/AX state as the fast structured source of truth; reserve screenshots for genuine visual judgment.
2. **The isolation-over-live-desktop default is universal for Computer Use, and this setup deliberately breaks it** — driving a real live desktop with real live workspaces is a harder, less-traveled path than the vendor's own recommended pattern. No off-the-shelf guardrails exist for that choice.
3. **Every generalist macOS-agent tool stops exactly at the window-manager boundary** — three unrelated projects plus the most funded Computer-Use infra project all converge on the same absence. Not a crowded lane.
4. **Background-without-focus-theft (cua-driver) and see-a-hidden-workspace (staging) are being solved as separate problems by separate people, not unified.** A stage→inspect→restore loop would be a genuine synthesis, not a reimplementation.
5. **Reliability/latency limits argue for calling vision rarely and deterministically**, not in a tight loop against a shifting multi-window scene.
6. **Tool metadata (GitHub PR "merged" flags, star counts, paginated release lists) was noisy enough to produce contradictory numbers within this research pass itself** — cross-check load-bearing facts against a second independent signal.

## 4. Where AeroSpace fits, and its gaps

AeroSpace is a better-than-expected starting substrate precisely because it was built CLI-first for humans, which happens to transfer well to scripts. It already clears the three lowest bars for agent use: structured JSON, ID-addressable targeting, and an event stream instead of polling. Concrete gaps:

- **No geometry** — confirmed absent from the CLI's field enum, not just undocumented. Anything needing frame/position must go through the Accessibility API directly.
- **No first-class "stage and restore" verb** — `move-node-to-workspace` and `workspace <name>` are raw primitives; nothing bundles "remember current workspace, switch, [inspect], switch back" with rollback semantics.
- **No dry-run** on any mutating command.
- **No workspace-role registry inside AeroSpace itself** — though (see below) this repo already has one externally.
- **The visibility gap is structural and permanent**, not a rough edge likely to be removed — any hybrid design has to treat "switch, screenshot, switch back" (or cua-driver's non-visual alternative) as the permanent physics of the system.

## 5. Concrete proposals

Ordered roughly by leverage-to-effort ratio; see `docs/plans/wmctl-window-manager-skill-2026-07-01.md` (claude-toolkit) for the buildable breakdown.

1. **`wmctl stage` / `wmctl restore` verb pair** — the actual missing primitive. `stage` reads current focused workspace, moves the target window into view (or focuses its workspace), confirms via the `subscribe` stream, and returns a small receipt token; `restore` reverses it. Computer Use slots in between the two calls.
2. **Dry-run as a first-class flag on every mutating verb** — prints the JSON diff of intended changes without calling AeroSpace. The single highest-leverage guardrail for trusting an agent on a live desktop.
3. **A workspace-role registry `wmctl` reads** — turns out this repo already has one (`nix/data/workspaces.toml`); `wmctl` should read it, not invent a new one.
4. **Prefer cua-driver-style background action over staging when the task is act-only** — reserve the full stage→screenshot→restore loop for genuinely visual judgments.
5. **A bounded "cockpit" contract, not free-roam access** — default agent-initiated moves to a stable cockpit workspace unless explicitly overridden.
6. **Geometry as an Accessibility-API side-channel, not an AeroSpace feature request** — call out to AX directly (or an existing MCP server) only when a specific operation needs frame data.

## 6. Verification experiments / next steps

1. Build and dogfood `wmctl stage`/`wmctl restore` against a real Computer-Use call on one low-stakes, easily-reversible task; manually verify the desktop ends up pixel-identical to its pre-stage state after restore.
2. Race-test the `subscribe` event stream against a rapid double-switch (stage, then trigger an unrelated human workspace change before restore) — confirm restore behaves safely rather than getting confused by the intervening action.
3. A/B an accessibility-only path against the stage-and-screenshot path on the same task to get an empirical latency/reliability comparison on this machine, rather than relying on general vendor guidance.
4. Run `aerospace subscribe --all` for an extended session and watch for dropped events or crashes before depending on it for restore-safety logic.

## 7. Caveats

- **The hybrid "CLI stages, Computer Use inspects, CLI restores" model is not attested anywhere in this research pass.** Every claim about it is a synthesis built from separately-verified adjacent primitives — not a description of an existing system. Section 5 is original proposals, not a survey of a solved problem.
- Two claims survived adversarial verification at only 2-1 (both concerning `trycua/cua`'s exact scale/release metadata) — traced to noisy tool output, not genuine factual disputes, but flagged as the softest evidence here.
- `wmux`/`cmux` are terminal multiplexers, not OS-level tiling window managers — useful as transferable design-pattern evidence only.
- cua-driver's "no cursor/focus/Space disruption" is a strong default, not a universal guarantee — canvas/gaming apps and some Chromium paths require real foreground activation.
- **Time sensitivity**: several sources (wmux v3.11.1, MacOS-MCP v0.3.8, AeroSpace's `subscribe` command, cua's latest push) are dated within days to weeks of 2026-07-01 — expect version specifics to be stale within a quarter.

## 8. Open questions

1. Does `cmux` (the macOS tmux-based agent multiplexer `wmux` says it was inspired by) already implement anything closer to the stage/inspect/restore loop at the terminal-pane level?
2. Would an Accessibility-API geometry read actually return usable frame data for AeroSpace-tiled windows, or does AeroSpace's own window manipulation interfere with what the AX tree reports?
3. How does cua-driver's SkyLight-based injection behave when the target window sits on an AeroSpace-emulated *inactive* workspace (physically moved offscreen, not merely occluded/minimized)? This determines whether the background-action shortcut (proposal 5.4 above) is viable for AeroSpace's specific hidden-workspace mechanism, versus the merely-occluded windows cua's own examples demonstrate.
4. Is there a smaller, safer first slice of `wmctl` than the full stage/restore pair — e.g. shipping the dry-run flag and a role-registry reader alone, with zero live-desktop mutation, as a lower-risk first increment?
