# Investigation: Logitech K120 function-key access on macOS

## Summary

The machine already has the software pieces needed to compensate for the K120's missing Fn/Globe key. Nix installs Karabiner-Elements, Home Manager links the repository's Karabiner directory into the live configuration, and the active profile maps the Application/Menu key to a synthetic Fn key. Karabiner 16.1.0, its permissions, and its virtual HID driver are healthy on the live Mac.

The current mapping may already solve the problem: bare F1–F12 remain standard function keys, Menu held with an F-key may invoke the alternate system action, and Menu tapped may follow macOS's “Change Input Source” Globe action. Static state cannot prove those physical-key behaviors. No Nix, macOS preference, or Karabiner change is justified until the K120 is tested in Karabiner-EventViewer.

If the existing path is incomplete, the first fallback is the already-enabled Control-Option-Space input-source shortcut. A K120-specific Karabiner rule is warranted only when EventViewer confirms the device and key events and synthetic Fn cannot provide the required actions.

## Symptoms

- The Logitech K120 exposes an F1–F12 row but has no `fn` or Globe key.
- macOS is configured to use F1–F12 as standard function keys, preserving custom function-key bindings and browser F12/DevTools behavior.
- Without an `fn`/Globe key, the same hardware cannot directly invoke the alternate media/system functions or the current Globe-key input-source switch.
- The desired outcome is access to standard F-keys, media/system actions, and quick Dvorak/ABC switching without sacrificing existing bindings.

## Background / Prior Research

- Logitech presents the K120 as a basic plug-and-play USB keyboard. Its official imagery and support material show F1–F12 but no Fn/Globe key, Fn Lock, secondary media legends, or documented alternate layer: https://www.logitech.com/en-us/shop/p/k120-usb-standard-computer and https://support.logi.com/hc/en-us/articles/360024322513--Getting-Started-Keyboard-K120.
- Apple documents that “Use F1, F2, etc. keys as standard function keys” makes bare top-row presses behave as F1–F12. On keyboards without Fn, Apple suggests trying Control plus a function key for the alternate behavior, but does not promise that this works for every external keyboard: https://support.apple.com/en-gb/102439.
- macOS already provides input-source shortcuts that do not require Globe: Control-Space selects the previous input source and Control-Option-Space selects the next: https://support.apple.com/en-euro/102650.
- Apple’s Modifier Keys pane exchanges modifier roles; it is not a general rule engine for modifier-plus-function-key media mappings: https://support.apple.com/en-gb/guide/mac-help/-mchlp1011/mac.
- Karabiner-Elements supports exact-device conditions and function-row/media mappings, but its documentation says it cannot modify a hardware Fn key on non-Apple keyboards. It can emit synthetic Fn through its virtual keyboard: https://karabiner-elements.pqrs.org/docs/getting-started/features/ and https://karabiner-elements.pqrs.org/docs/json/expert-complex-modifications-examples/swap-function-keys-on-external-keyboards/.
- Logitech does not publish a K120 HID report descriptor in the reviewed material. The exact unit should be observed with Karabiner-EventViewer before any device-specific rule uses vendor/product identifiers: https://karabiner-elements.pqrs.org/docs/manual/operation/eventviewer/.

## Investigator Findings

### Executive conclusion

The machine **already has a viable, but not yet behaviorally proven, K120 alternate-layer path**. The active Karabiner profile globally remaps an `application` (Application/Menu) key event to Karabiner's synthetic `keyboard_fn`; Karabiner and its virtual HID driver are running; the live config is the repo config; macOS has standard F-keys enabled; and the live Fn/Globe preference matches the supplied screenshot's “Change Input Source” selection. This makes one Menu key capable *in principle* of acting as held Fn for the F-row and as a tapped Globe key.

Static inspection does not prove three independent runtime facts: (1) this physical keyboard's Menu key emits `application`, (2) held synthetic `keyboard_fn` reverses the standard-F-key setting for this external F-row, or (3) a standalone synthetic Fn tap is accepted as a Globe tap. All three require EventViewer/key-press outcome testing. The attached Logitech device is identified by the system as `USB Keyboard`, not explicitly as `K120`, so its observed identifiers must also be confirmed by unplug/replug or EventViewer before any exact-device rule is authored.

If synthetic Fn is unreliable, the safest deterministic fallback is an **exact-device Karabiner variable layer**: an observed spare key (prefer Menu if it emits) sets a layer while held; layer+F keys emit only the explicitly desired consumer/Apple-vendor actions; and a tap emits the already-enabled Control-Option-Space “next input source” shortcut. Bare F1-F12 remain untouched. Do not stack that fallback on the existing global Menu→Fn rule.

### 1. Exact repository ownership

| Concern | Canonical ownership and evidence |
| --- | --- |
| Host entry point | `nix/flake.nix:42-50` builds `darwinConfigurations."m5-mbp"` and loads `nix/hosts/m5-mbp/configuration.nix` plus Home Manager. |
| Host modules | `nix/hosts/m5-mbp/configuration.nix:4-7` imports `homebrew.nix` and `defaults.nix`; `nix/hosts/m5-mbp/configuration.nix:76-82` assigns `users.mp` to `nix/home/mp/darwin.nix`. |
| Karabiner install | `nix/hosts/m5-mbp/homebrew.nix:47-56` declares the `karabiner-elements` cask. This is the active Nix-migration ownership path. |
| Karabiner config module | `nix/home/mp/darwin.nix:4-21` imports `modules/karabiner.nix`. `nix/home/mp/modules/karabiner.nix:3-5,8-29` maps the whole `~/.config/karabiner` directory to the repo's `karabiner/` directory with `mkOutOfStoreSymlink` and `force = true`, explicitly documenting that it is a live directory mapping. |
| Global Menu→Fn rule | The selected `Default profile` has a profile-level simple modification from `application` to `apple_vendor_top_case_key_code: keyboard_fn` at `karabiner/karabiner.json:293-305`. It is outside the `devices` array and therefore is not K120-specific. |
| Existing device block | `karabiner/karabiner.json:267-290` swaps Command/Option only for vendor `1241` (`0x04d9`), product `36` (`0x0024`). It does not match the attached Logitech device and is not the candidate K120 layer. |
| macOS keyboard defaults | `nix/hosts/m5-mbp/defaults.nix:10-32` declares repeat/typing preferences but not function-row, Fn/Globe, or input-source state. `nix/hosts/m5-mbp/defaults.nix:173-193` explicitly disables symbolic hotkey 60, Control-Space, to reserve it for applications. |

Legacy ownership hypotheses were eliminated: `Brewfile:84`, `Makefile:37-45`, and `install-osx-dev-apps.sh:58-62` contain older install/symlink mechanisms, but `AGENTS.md:5-10` marks non-`nix/` setup as mostly legacy and prefers Nix ownership. The live Home Manager link described below confirms that those legacy paths do not own the current config.

### 2. Live Karabiner installation, profile, link, and health

Read-only commands run on 2026-08-13:

```sh
plutil -extract CFBundleShortVersionString raw -o - \
  /Applications/Karabiner-Elements.app/Contents/Info.plist
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --version
ps -axo pid,uid,command | grep -i '[k]arabiner'
launchctl print gui/$(id -u) | grep -i -A3 -B2 pqrs
```

Evidence:

- The installed app and CLI both report **16.1.0**.
- Running components include `Karabiner-Core-Service`, `karabiner_console_user_server`, `Karabiner-Menu`, `Karabiner-NotificationWindow`, the DriverKit VirtualHIDDevice daemon, and the loaded VirtualHIDDevice system extension.
- The user launchd domain reports the Karabiner Menu, NotificationWindow, console server, and Core Service jobs enabled/running.
- `~/.local/share/karabiner/tmp/core-service-permission-check-result.json` reports both `accessibility_process_trusted: true` and `iohid_listen_event_allowed: true`.
- Karabiner's debug logs contain recurring transient service timeouts/disconnections followed by reconnection. The current services, successful CLI queries, active virtual device, and permission check do not indicate a persistent disabled/broken state, but the reconnect noise is worth remembering if manual tests are intermittent.

The Homebrew receipt query returned `karabiner-elements 15.7.0` while the running app and CLI report 16.1.0. That version drift does not invalidate the loaded mapping, but it means the receipt alone is not authoritative for the currently running bundle.

Live config/profile commands:

```sh
readlink ~/.config/karabiner
realpath ~/.config/karabiner
cmp -s ~/.config/karabiner/karabiner.json karabiner/karabiner.json; echo $?
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli \
  --show-current-profile-name
```

Salient output:

```text
~/.config/karabiner -> /nix/store/...-home-manager-files/.config/karabiner
realpath -> /Users/mp/Projects/personal/dotfiles/karabiner
cmp exit -> 0
profile -> Default profile
```

Conclusion: the active profile named in `karabiner/karabiner.json:293-305` is selected, and its live JSON is byte-identical to the repo. This proves that the Menu→synthetic-Fn rule is available to Karabiner; it does not prove a physical Menu event or the resulting macOS action.

### 3. Attached Logitech device visibility and identifiers

Commands:

```sh
/Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli \
  --list-connected-devices
ioreg -p IOUSB -l -w0
hidutil list
```

Karabiner, IORegistry, and `hidutil` agree on one attached Logitech USB keyboard:

```text
manufacturer: Logitech
product: USB Keyboard
transport: USB
vendor_id: 1133 / 0x046d
product_id: 49995 / 0xc34b
location_id: 1114112 / 0x110000
interfaces: keyboard (usage page 1, usage 6) and consumer control (usage page 12, usage 1)
```

The IDs are observed, not invented. However, the USB descriptor exposes only the generic product string `USB Keyboard`; system state does **not** contain the model string `K120`. Treat `0x046d:0xc34b` as the attached Logitech candidate, not as a conclusively model-labelled K120, until unplug/replug or EventViewer ties it to the physical unit. The consumer-control interface also does not prove a hidden hardware media layer; a composite keyboard may expose that interface without any physical key producing consumer events.

The repo's only device block (`0x04d9:0x0024`, `karabiner/karabiner.json:267-290`) is absent from Karabiner's connected-device list. No current repo rule or `device_if` condition targets `0x046d:0xc34b`.

### 4. Live macOS function-row, Globe/Fn, and input-source state

Commands and output:

```sh
$ defaults read -g com.apple.keyboard.fnState
1

$ defaults read com.apple.HIToolbox AppleFnUsageType
1

$ defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID
com.apple.keylayout.Dvorak

$ defaults read com.apple.HIToolbox AppleEnabledInputSources
Dvorak, ABC, CharacterPalette
```

Correlation:

- `com.apple.keyboard.fnState = 1` matches the supplied screenshot and report symptom that “Use F1, F2, etc. keys as standard function keys” is enabled (`docs/investigations/2026-08-13-logitech-k120-function-keys.md:7-12,239`). Bare F1-F12 should therefore remain standard keys unless Fn semantics reverse them.
- `AppleFnUsageType = 1` is stored in `com.apple.HIToolbox` and is consistent with the supplied screenshot's “Press Globe key to: Change Input Source.” Because this is not declared in `defaults.nix`, the screenshot and an actual tap remain the strongest semantic confirmation; the numeric preference alone should not be over-decoded.
- Dvorak is current; Dvorak and ABC are the two enabled keyboard layouts. CharacterPalette is a non-keyboard input method. An input-source “next” action should therefore cycle the two keyboard layouts in the current state, but that behavior should be observed rather than assumed from the list alone.

Symbolic hotkeys were exported read-only from `com.apple.symbolichotkeys`:

```text
60: enabled=false, parameters=[32,49,262144]  # Control-Space
61: enabled=true,  parameters=[32,49,786432]  # Control-Option-Space
```

Hotkey 60 exactly matches the declarative activation write at `nix/hosts/m5-mbp/defaults.nix:178-193`; it is deliberately unavailable for input switching. Hotkey 61 is enabled but undeclared. Therefore Control-Option-Space is the safest already-present input-switch fallback and must be used instead of re-enabling or stealing Control-Space.

No repo declaration was found for `com.apple.keyboard.fnState`, `AppleFnUsageType`, enabled/selected input sources, or hotkey 61. Those live states may drift and are not reproduced by the current Nix configuration.

### 5. Existing keybinding claims and conflicts

Repo evidence:

- CapsLock is independently remapped to Hyper while held and LeaderKey when tapped at `karabiner/karabiner.json:30-43`; Hyper+Space becomes Escape at `karabiner/karabiner.json:220-230`. These use a different physical trigger and do not conflict directly with Menu→Fn.
- The keybinding inventory records `application → keyboard_fn` and the unrelated device modifier swaps at `keybinds/generated/INVENTORY.md:28-33`.
- A focused repo search found no active F1-F12 mapping in the Nix/Karabiner/AeroSpace/Kitty sources. The only config-like match outside comments was a commented legacy Hyper-F3 line at `yabai/skhdrc:245-247`. Bare F12 remains available to browsers as far as repo-owned bindings show.
- Control-Space ownership is explicit only in `nix/hosts/m5-mbp/defaults.nix:178-193`, where it is disabled for macOS input switching and reserved for applications such as Neovim autocomplete.
- `hidutil property --get UserKeyMapping` returned `(null)`, so there is no separate live global `hidutil` remap layer competing with Karabiner.
- `keybinds/generated/CONFLICTS.md:1-5` says “No conflicts detected,” but it was generated on 2025-12-31. It is stale, does not prove current live app preferences, and may not model device-variable layers even after regeneration.

Scope limit: “no active F1-F12 conflict found” applies only to searched repo-owned configuration. Browser defaults, app-local preferences, macOS behaviors outside symbolic hotkeys 60/61, and other live automation/global-hotkey apps were not exhaustively provable from the repo.

### 6. Hypothesis assessment: held media layer plus tap input switching

The existing simple modification preserves an Application key's down/up lifecycle while changing its output to Karabiner's synthetic `keyboard_fn` (`karabiner/karabiner.json:296-300`). Karabiner's virtual HID keyboard is running, `fnState=1` asks Fn to reverse standard F-keys, and the live Fn/Globe preference matches “Change Input Source.” The report's prior research also establishes that Karabiner can emit synthetic Fn through its virtual keyboard (`docs/investigations/2026-08-13-logitech-k120-function-keys.md:14-21`). Together, this is a coherent and low-change path.

The behavior nevertheless splits into three separately testable claims:

| Claim | Static status |
| --- | --- |
| Physical K120 Menu emits `application` with normal down/up events | **Unknown.** The USB descriptor and device list cannot prove an actual key usage. |
| Holding Menu-generated `keyboard_fn` while pressing F1-F12 invokes the expected alternate media/system actions | **Plausible, unverified.** Config, virtual HID, and `fnState=1` support it; only key presses prove macOS treatment and the exact per-F-key actions. |
| Tapping Menu-generated `keyboard_fn` switches Dvorak/ABC once | **Plausible, unverified.** `AppleFnUsageType=1` and the screenshot support it; synthetic Fn might be handled differently from a physical Globe tap. |

Held Menu+F may work while tap-to-switch does not, or vice versa. A combo must also be checked to ensure releasing Menu after Menu+F does **not** accidentally trigger an input-source switch.

### 7. Eliminated hypotheses

- **“Karabiner is absent or not running.”** Eliminated by app/CLI 16.1.0, running core/console/menu/virtual-HID processes, launchd state, and trusted permissions.
- **“The live profile is not the repo profile.”** Eliminated by active profile `Default profile`, Home Manager link resolution, and byte-identical JSON.
- **“The existing Menu→Fn rule is scoped to some other keyboard.”** Eliminated: it is profile-global at `karabiner/karabiner.json:293-301`. The nearby `1241:36` block is a separate Command/Option swap.
- **“Control-Space is an available fallback.”** Eliminated: live hotkey 60 is disabled exactly as `defaults.nix` declares. Control-Option-Space/hotkey 61 is the available shortcut.
- **“The existing `1241:36` block identifies the Logitech/K120.”** Eliminated by live Logitech IDs `1133:49995`.
- **“The consumer HID interface proves built-in media keys.”** Eliminated as an inference; interface presence alone says nothing about which physical usages the keyboard emits.
- **“The repo conflict report proves the layer is conflict-free.”** Eliminated: the report is stale and repo-only.

### 8. Required manual validation gate

Use Karabiner-EventViewer and visible outcomes; do not change preferences first:

1. In EventViewer's Devices view, unplug/replug the K120 and confirm that the `Logitech / USB Keyboard / 0x046d:0xc34b` keyboard and consumer entries disappear/reappear.
2. Press bare F1, a middle key, and F12. Confirm they arrive/behave as standard F-keys and that bare F12 still reaches browser DevTools.
3. Press the Menu key alone. Confirm an event is observed and that the active rule produces `keyboard_fn`; record whether the input source changes exactly once.
4. Hold Menu and press representative alternate keys: F1/F2, F3, F8, and F10-F12. Record the actual action for each—do not assume Apple legends or that every F-key has a useful alternate.
5. Confirm Menu remains held for the chord, the F-key action occurs on the intended edge, bare F-keys remain unchanged afterward, and releasing Menu after a chord does not switch input source.
6. Separately test Control-Option-Space. This establishes the no-Karabiner input-switch fallback before any rule is designed.
7. If Menu emits no usable event, use EventViewer to select another genuinely spare K120 key; do not guess a key code from product images.

### 9. Safest fallback hierarchy

1. **Input switching only:** use the already-enabled Control-Option-Space/hotkey 61. This requires no config or preference change.
2. **Try the existing global path unchanged:** it is already loaded, so testing has lower risk than adding another rule. Verify all three claims above.
3. **If held synthetic Fn works but tap does not:** avoid blindly stacking a `to_if_alone` shortcut on the global synthetic-Fn output, because a later macOS change could make both tap paths fire and switch twice. Design a device-scoped, explicitly tested tap/hold rule instead.
4. **If synthetic Fn+F fails:** replace—not stack with—the global Menu→Fn mapping using an exact-device complex-modification layer after confirming the physical IDs:
   - Menu key-down sets a uniquely named K120 layer variable; key-up/reset clears it.
   - Every Menu manipulator and every layer+F manipulator has the same exact-device condition; Karabiner variables are otherwise global.
   - Layer+F mappings emit only the desired explicit outputs. Volume/playback are consumer events; Mission Control/Launchpad or similar functions may require Apple-vendor codes. Do not create a blanket “media” assumption.
   - Menu `to_if_alone` emits Control-Option-Space, with an intentional tap timeout.
   - Bare F1-F12 pass through unchanged.
   - Test disconnect-while-held so the layer cannot remain stuck.
5. **If Menu emits nothing:** substitute another EventViewer-confirmed spare key only within the exact-device layer.

The exact-device fallback is safer than using Control or Hyper as the layer modifier: it avoids the repo's deliberate Control-Space ownership, avoids the existing CapsLock/Hyper ecosystem, preserves bare F1-F12, and contains the behavior to the confirmed external keyboard.

### 10. Explicit unknowns after read-only investigation

- Whether `0x046d:0xc34b` is conclusively the physical K120 rather than another attached Logitech keyboard with the generic `USB Keyboard` descriptor.
- Whether the K120 Menu key emits `application`, a different usage, or nothing visible to Karabiner.
- Whether synthetic `keyboard_fn` from a non-Apple external keyboard is treated as held Fn for each desired F-key action on this macOS/Karabiner version.
- Whether a standalone synthetic Fn tap is treated as Globe and follows `AppleFnUsageType=1`.
- Whether Menu+F release suppresses the tap-to-change-input action.
- The desired exact action set for F1-F12; the physical K120 has no Apple secondary legends and the report's reviewed Logitech material documents no alternate layer.
- Live conflicts in browser/app-specific preferences or untracked global-hotkey applications.
- Why Homebrew's cask receipt reports 15.7.0 while the installed/running bundle reports 16.1.0; this is operational drift, not evidence against the mapping itself.


## Investigation Log

### Initial assessment - behavior split to verify

**Hypothesis:** The K120 sends ordinary USB HID F1–F12 usages but lacks a hardware `fn`/Globe event; macOS can remap ordinary modifiers or shortcuts but cannot synthesize a missing Apple hardware-layer toggle through the existing Function Keys setting alone.

**Findings:** The K120 exposes ordinary F-keys and no documented hardware Fn layer. The machine already supplies a synthetic Fn path through Karabiner's global Application/Menu mapping. That authored path is active and healthy, but its physical behavior remains unverified.

**Evidence:** The supplied System Settings screenshots show “Use F1, F2, etc. keys as standard function keys” enabled and “Press Globe key to” set to “Change Input Source.”

**Conclusion:** The repository does not need a new keyboard stack. Manual key-event testing must determine whether the existing mapping is sufficient or whether a small exact-device rule is needed.

## Root Cause

The K120 lacks the hardware Fn/Globe key that normally selects the alternate meaning of a Mac function row. The macOS “standard function keys” preference only chooses which meaning bare F1–F12 receive; it cannot create the missing physical layer trigger.

This machine already compensates in software by mapping the Application/Menu key to synthetic Fn at `karabiner/karabiner.json:293-305`. The remaining problem is validation rather than missing configuration: the keyboard's USB descriptor does not prove what its Menu key emits, and static configuration cannot prove how macOS handles the synthetic Fn key when tapped or held with the K120's F-row.

The configuration is also only partly reproducible through Nix. Karabiner installation and its repo-backed config link are declarative, but `com.apple.keyboard.fnState`, `AppleFnUsageType`, input-source ordering, and enabled symbolic hotkey 61 are live preferences not declared in `nix/hosts/m5-mbp/defaults.nix`. Control-Space is intentionally unavailable because `defaults.nix:178-193` disables it for application use.

## Recommendations

1. **Make no configuration change before testing.** In Karabiner-EventViewer, unplug and reconnect the K120 candidate and confirm that device `0x046d:0xc34b` disappears and returns. This ties the generic `USB Keyboard` descriptor to the physical unit.
2. **Test the existing mapping.** Verify bare F1 and F12, Menu alone, Menu held with representative brightness/playback/volume F-keys, and Menu release after a chord. A successful result preserves literal F-keys, performs the desired alternate actions, switches Dvorak/ABC exactly once on a Menu tap, and does not switch input sources after a Menu+F chord.
3. **Test the two no-change fallbacks.** Confirm Control-Option-Space switches Dvorak/ABC exactly once, and try Apple's documented Control-plus-function-key behavior on representative F-keys.
4. **Use Control-Option-Space when only input switching is missing.** Symbolic hotkey 61 is enabled on the live Mac. Do not re-enable Control-Space; the Nix configuration deliberately reserves it for applications such as Neovim autocomplete.
5. **Use a small exact-device dual-role rule when held synthetic Fn works but tapping does not.** Scope the rule to the EventViewer-confirmed Logitech IDs, send synthetic Fn while held, and send Control-Option-Space only when tapped alone. Replace the global Menu mapping for that device rather than stacking a second tap path on it.
6. **Use an explicit variable-backed F-row layer only when synthetic Fn fails and several alternate actions are required.** Keep bare F1–F12 unchanged, emit only the chosen consumer or Apple-vendor actions, apply the exact-device condition to every manipulator, and verify that disconnecting the keyboard while the layer is held cannot leave it stuck.
7. **Keep future ownership in the current architecture.** A keyboard rule belongs in `karabiner/karabiner.json`; Karabiner installation remains in `nix/hosts/m5-mbp/homebrew.nix`; any reliable macOS preference declaration belongs in `nix/hosts/m5-mbp/defaults.nix`. The legacy Makefile and install script are not ownership surfaces.

## Preventive Measures

- Capture vendor/product IDs and source events from EventViewer before authoring device conditions; do not infer identity from the generic USB descriptor or reuse the unrelated `1241:36` block.
- Regenerate the keybinding inventory and inspect live app shortcuts before adding a rule. The committed conflict report is stale and the current extractor does not fully model device conditions on complex Karabiner rules.
- If a complex device-scoped layer becomes necessary, extend the Karabiner extractor so the conflict inventory preserves its device scope.
- If the function-row, Globe action, or hotkey 61 state becomes a required dependency, declare it through the supported Nix/macOS defaults surface or document a script/runbook bridge so a fresh Mac does not depend on manual drift.
- Treat the Homebrew receipt/app version mismatch as a separate operational drift check; the installed app and running CLI report 16.1.0 while the cask receipt reports 15.7.0.
