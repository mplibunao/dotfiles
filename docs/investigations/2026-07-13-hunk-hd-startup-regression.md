# Investigation: Hunk `hd` startup regression

## Summary

The slowdown is real in Kitty and begins at Hunk 0.14.0. In the same Kitty window and `claude-toolkit` repository, Hunk 0.13.2 took 1.21 seconds to show its first complete frame, while Hunk 0.14.0 took 4.60 seconds. Hunk 0.17.0 took 4.78 to 7.43 seconds. The `hd` wrapper, broker port, and configured theme don't explain that gap.

The missing Ember appearance is a separate upgrade effect. Hunk 0.17.0 accepts `theme = "ember"`, but its source maps that legacy name to `dark-plus`. Hunk 0.13.2 retains Ember as a distinct bundled palette.

The local resolution pins Hunk 0.13.2 and retains `theme = "ember"`. Catppuccin Mocha first appears in Hunk 0.14.0, so the fast pin and that theme aren't available together without a downstream theme backport.

Upstream tracking: [modem-dev/hunk#534](https://github.com/modem-dev/hunk/issues/534).

## Upgrade scope

- The dotfiles upgrade moved Hunk from revision `4f70481a60fa71b2cc73e2872fa9f62514528a3a` (0.12.0) to `059dd13c8bd27fe503ef59652077edf0041034c8` (0.17.0) in commit `9d2a1bd1a4eb59d03dfb364a5d2d29cc9e0e97bf`.
- Commit `719b25ead354d8991c7cd584a07ef9b589f14bcb` changed Hunk's nixpkgs relationship for evaluation compatibility without changing the Hunk revision or `hd.fish`.
- The upgrade didn't change `hd.fish`. The wrapper still translates only a first argument of `staged` to `--staged`; all other arguments pass directly to `hunk diff`.
- The regressed binary was the locked Hunk 0.17.0 output at `/nix/store/h0fgv2mkdp6rxf173dc773n2mxpdc29s-hunkdiff-0.17.0/bin/hunk`. It's native arm64.
- The remediation pins revision `d619dbc4adb2407c5ad413b791acec5d8539819b`, the Hunk 0.13.2 release.

## Findings

### Actual Kitty comparison

The authoritative test launched each version from an already-running fish shell in the same native Kitty tab, with `claude-toolkit` as the working repository. Computer Use polled the Kitty window until the first complete Hunk frame appeared.

| Launch | First complete frame |
| --- | ---: |
| Hunk 0.17.0: `hd main` | 4.97 s |
| Hunk 0.17.0: `hd main --theme dark-plus` | 7.43 s |
| Hunk 0.17.0: `hd main --theme dark-plus`, private broker port | 4.78 s |
| Hunk 0.16.0: private broker port, `ember` | 2.32 s |
| Hunk 0.15.3: private broker port, `ember` | 4.21 s |
| Hunk 0.14.1: private broker port, `ember` | 4.34 s |
| Hunk 0.14.0: private broker port, `ember` | 4.60 s |
| Hunk 0.13.2: private broker port, `ember` | 1.21 s |
| Hunk 0.13.0: private broker port, `ember` | 1.33 s |
| Hunk 0.12.0: `hunk diff main --theme ember`, private broker port | 1.40 s |

Screenshot polling introduces small timing error, and Hunk 0.17.0 varies between launches. The 3.39-second jump from 0.13.2 to 0.14.0 is much larger than polling error. A Hunk 0.17.0 session launched at `08:14:09.868Z` and first updated at `08:14:16.877Z`, independently corroborating a 7.01-second current-version launch.

This same-terminal comparison supersedes the isolated pseudo-terminal (PTY) benchmark for user-perceived startup. The PTY harness reported 0.6 to 0.9 seconds because it answered terminal capability probes and used terminal output quiescence as the render boundary. It didn't reproduce Kitty's interactive startup path.

### `hd` wrapper

- `nix/home/mp/modules/fish/functions/hd.fish:44-47` builds the argument list and translates only the convenience argument `staged` to `--staged`.
- The normal path at `hd.fish:57` executes `command hunk diff $hunk_args`. The child-fish path is used only for `hd wt`.
- A fake-Hunk capture confirmed exact pass-through for revision, staged, and path-filter arguments. Three `hd` calls produced three direct Hunk child processes.
- The measured wrapper overhead was approximately 0.040 milliseconds per invocation.

No wrapper flag migration was missed, and changing `hd` can't recover a multi-second delay.

### Theme semantics

The Home Manager configuration at `nix/home/mp/darwin.nix:31-40` writes:

```toml
theme = "ember"
```

The deployed `~/.config/hunk/config.toml` contains that value, proving that the global config is present. In the 0.17.0 source, [`shikiThemes.ts`](https://github.com/modem-dev/hunk/blob/059dd13c8bd27fe503ef59652077edf0041034c8/src/ui/lib/shikiThemes.ts) defines `ember` as a legacy alias for `dark-plus`. The [0.14.0 changelog](https://github.com/modem-dev/hunk/blob/aab17a8f1a70f7d39412d9fd46c446b3ef1dc550/CHANGELOG.md#0140---2026-05-26) records the introduction of Catppuccin themes. Hunk 0.13.2 supports only Graphite, Midnight, Paper, and Ember.

The visual comparison matches the source: Hunk 0.13.2 renders Ember with its warm brown palette, while Hunk 0.17.0 renders the gray Dark Plus palette. Explicitly selecting `dark-plus` on 0.17.0 remained slow, so the alias explains the missing appearance but not startup performance.

### Causes eliminated

| Candidate | Evidence | Conclusion |
| --- | --- | --- |
| `hd` wrapper | Direct execution, exact argument capture, about 0.040 ms overhead | Not responsible |
| Legacy `ember` alias | Explicit `dark-plus` took 7.43 s | Appearance change only |
| Default broker contention | Private broker launch took 4.78 s | Not responsible |
| Architecture mismatch | Active executable is native arm64 | Not responsible |
| Repository choice | Old and new ran in the same `claude-toolkit` checkout | Controlled in A/B |
| Terminal or workspace choice | Old and new ran in the same Kitty tab and workspace | Controlled in A/B |

Earlier isolated tests also found no repo-size scaling and no multi-second contribution from `watch`, agent notes, line numbers, wrapping, fish autoload, or daemon startup. Those tests remain useful for eliminating configuration dimensions, but not for estimating interactive Kitty startup.

## Root cause

Two upgrade effects are present:

1. **Appearance:** Hunk's 0.16 theme-system migration removed Ember as a distinct palette and retained `ember` only as an alias for `dark-plus`. The existing config produces a different appearance without producing an error.
2. **Performance:** Hunk 0.14.0 introduced a real interactive startup regression relative to 0.13.2. The same-Kitty comparison places the regression inside Hunk's 0.14 runtime or rendering changes, not in `hd`, the global theme value, broker contention, the repository, or architecture. Hunk 0.16.0 improves the delay but doesn't restore 0.13.2 performance.

The release boundary is 0.13.2 to 0.14.0. The available measurements don't identify the exact commit within the 0.14.0 release cycle.

## Recommendations

1. Leave `hd.fish` and its completions unchanged. No wrapper migration is required.
2. Pin Hunk 0.13.2 as the newest measured fast release until upstream resolves the regression.
3. Keep `theme = "ember"` while pinned to 0.13.2. Catppuccin requires Hunk 0.14.0 or newer, which is inside the slow range.
4. Re-run the same Kitty launch-to-first-frame comparison before removing the pin. Don't add startup flags to `hd`.

## Preventive measures

Future Hunk bumps should record the lock revision, version, architecture, store path, and `hunk skill path`. They should compare the configured theme identifier with the supported identifiers and run an actual Kitty launch-to-first-frame comparison. A screenshot comparison should accompany the timing check so compatibility aliases can't change the configured appearance unnoticed.
