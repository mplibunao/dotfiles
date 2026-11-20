# Retrospective ledger: accidental terminal close protection

Request: none · Plan: `docs/exec-plans/completed/accidental-terminal-close-protection-2026-08-23.md` in `mplibunao/dotfiles-private`

`cmd+W` could close a Kitty tab and end the long-running agent session in it. The root cause was that the Karabiner guards named physical QWERTY keys, so under Dvorak they guarded the wrong keys. This work, planned and committed on 2026-08-23 and 2026-08-24 and merged on 2026-08-25, fixed the guards, blocked the accidental-close shortcuts in Kitty, and added a launch log to `clm` so a session's MCP configuration is still on disk after its tab closes. [Kitty](../architecture/kitty.md) describes the resulting behavior.

| Item | Outcome |
|------|---------|
| 1. Kitty settings and bindings | done |
| 2. Karabiner guards aimed at the right physical keys | done |
| 3. `clm` launch log | done |
| 4. Manual key-press checks | not verified |

## 1. Kitty settings and bindings

- Decision: map the accidental-close shortcuts to `discard_event` rather than `no_op`, because `no_op` passes the key through to a terminal app running in the tab. Set `confirm_os_window_close = -1` so Kitty asks only when a pane looks busy, and pin `close_on_child_death = no`. Source: the plan.
- Decision: no terminal multiplexer. Once the keybinding fix removes the trigger, a closed tab no longer kills the process in the reported failure. If this is revisited, herdr is the candidate, after its open issues on session restore, missing Claude messages, idle reporting during MCP calls, and CPU growth are fixed. Source: the plan.
- Evidence: `feat(kitty): neutralize accidental close shortcuts, confirm when busy` (2026-08-23), merged on 2026-08-25.
- Evidence (checked 2026-11-20): the running system matches this repository's configuration, and the generated `~/.config/kitty/kitty.conf` maps `cmd+w`, `ctrl+shift+q` and `shift+cmd+w` to `discard_event` and `cmd+q` to `quit`, with `confirm_os_window_close -1` and `close_on_child_death no`.

## 2. Karabiner guards aimed at the right physical keys

- Decision: `cmd+W` is blocked only in Kitty; browsers and Finder keep it, because a closed browser tab can be reopened and a closed Kitty tab costs an agent session. `cmd+Q` quits only on a double tap, in every app. Both rules match either Command key. Fixing the misaimed rule also gave `cmd+,` back to other apps. Source: the plan.
- Evidence: `fix(karabiner): aim close guards at the right physical keys under Dvorak` (2026-08-23), and `fix(karabiner): aim the hyper sysdiagnose guards at the characters they name` (2026-08-24), which aimed three Hyper guards at the physical keys that produce the characters their descriptions name. Both merged on 2026-08-25. The same work changed the keybinding inventory tool to report physical key positions separately from layout characters and regenerated its inventories. That tool isn't part of this repository.
- Evidence (checked 2026-11-20): `~/.config/karabiner/karabiner.json` is identical to `karabiner/karabiner.json` in the checkout, which has both rules.
- Deferred: whether macOS recognizes its sysdiagnose shortcut by the produced character or by the physical key is unresolved. The guards assume the character. Pressing Hyper+`v` after relaunching Karabiner would show the key-based reading if sysdiagnose starts; if nothing happens, the result is inconclusive, because another app appears to own that chord.

## 3. `clm` launch log

- Decision: `clm` appends each launch's MCP configs, arguments, and working directory to `~/.local/state/clm/launches.jsonl`, and Claude still starts when the log can't be written. Source: the plan.
- Evidence: `feat(clm): record each launch's MCP configs to a JSONL state log` (2026-08-23), with follow-ups that keep logged config names replayable and skip the log unless the user owns the state directory (2026-08-24). Logged arguments can include prompt text, and `chmod` can't set mode 0700 on a directory the user doesn't own.
- Evidence (checked 2026-11-20): the log exists with 209 entries, each with `args`, `at`, `configs` and `cwd`. The newest was written on 2026-11-03.

## 4. Manual key-press checks

- Deferred: the plan's manual checks have no recorded results: not verified. They cover `cmd+W` and its sibling shortcuts on the built-in keyboard and both external keyboards, Kitty with Karabiner quit, `cmd+,` in Finder and in Kitty, `cmd+W` in Chrome, the `cmd+Q` double tap with and without a busy pane, `kt close` and `kdev`, and the launch log's unwritable-path case. The plan's commit table still said "push pending" when the branch merged. The merge on 2026-08-25 is what shows delivery.
