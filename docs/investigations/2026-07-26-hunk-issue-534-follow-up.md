# Investigation: Hunk issue 534 follow-up

## Summary

Hunk v0.17.4 shipped the macOS renderer-threading change linked from `modem-dev/hunk#534`, and v0.17.6 is the newest release containing that change. Local testing on the original small fixture found no startup regression in v0.17.6, so issue 534 was closed as resolved for its original scope. PR 539 explicitly limits its claim to a v0.17-era threading regression, so the local result establishes the practical outcome without attributing the older 0.14.0 regression to that change.

The controlled `HEAD~5` fixture shows that v0.17.6 removes the original multi-second startup delay, but production-scale validation exposed a separate wrapping failure, now tracked as `modem-dev/hunk#600`. On the 141-file `claude-toolkit` branch diff, v0.17.6 remained blank with wrapping enabled and held about 1 GB before termination. Because wrapping is required for normal review, the final decision restores v0.13.2 with `wrap_lines = true` and `watch = false`. The literal `hd main` path rendered the full diff in 2.83 seconds and responded to navigation under that exact combination.

## Symptoms

- Hunk 0.14.0 through 0.17.0 rendered its first complete frame materially slower than 0.13.2 in the same Kitty environment.
- The prior Home Manager generation used Hunk 0.13.2 as a workaround.
- The `hd` Fish helper was previously measured as negligible overhead and is not expected to require changes.

## Background / Prior Research

- The original investigation is `docs/investigations/2026-07-13-hunk-hd-startup-regression.md`.
- Upstream tracking issue: https://github.com/modem-dev/hunk/issues/534
- Wrapped large-diff follow-up: https://github.com/modem-dev/hunk/issues/600
- The issue timeline links PR https://github.com/modem-dev/hunk/pull/539, `fix(ui): restore threaded rendering on macOS`.
- PR 539 removed Hunk's `useThread: false` override so OpenTUI can use its optimized macOS renderer default.
- PR 539 merged on 2026-07-23 as `b358e0c92eabaa35529d3f3d9afaad2944c825e4`.
- Hunk v0.17.4 shipped the fix on 2026-07-23. Its tagged changelog records the shipped equivalent as `a9b8694cd6bd1e0b7dfc77cf4e7a07e67677618a`.
- Hunk v0.17.6 is the newest published release. It separately adds PR 586's wide-character cell-width optimization and PR 590's headless native-library loading fix.
- Issue 534 had no maintainer-provided Kitty timing against the 0.13.2 baseline. The local A/B validation supplied that missing upgrade evidence, and the issue was closed on 2026-07-26 after the separate wrapping failure was filed as issue 600.
- Relevant changes since 0.13.2 include renderer and virtualization performance work, broader performance benchmarks and release gates, inline expansion of collapsed context, OSC 52 copying, improved CJK/emoji alignment, additional themes, Sapling support, review-note improvements, and terminal/security hardening.
- Migration-sensitive changes include `q` replacing global Escape-to-quit behavior in 0.17.0 and the 0.16.0 theme-system/default-theme change.

## Investigator Findings

Investigated 2026-07-26. All four propositions hold. Two are broader than recorded, one is narrower in scope, and the recorded description of PR 539's contents needs correction.

| # | Proposition | Verdict | Decisive evidence |
| --- | --- | --- | --- |
| 1 | The workaround is solely the lock revision; `hd` needs no renderer workaround | Confirmed | `71443e7` touched only `nix/flake.lock` (6 lines); PR 539's entire runtime change deletes one line |
| 2 | `nixpkgs-pre2611` must remain independently of the Hunk pin | Confirmed, and broader | Four consumers, not two; Hunk still enumerates `x86_64-darwin` at v0.17.6 |
| 3 | Local theme/completion/keyboard/pager behavior needs explicit migration review | Confirmed, narrower scope | Every config key still parses; the theme *value* and the completion menu are the real exposure |
| 4 | Upstream shipment doesn't yet establish restored real-Kitty performance | Confirmed | Issue 534 has zero comments; PR 539 states validation is still required |

### F1. The pin is exactly one lock revision, and no renderer workaround exists locally

The Hunk input is declared without a revision, so the pin exists only as a resolved lock entry:

- `nix/flake.nix:26-29` declares `url = "github:modem-dev/hunk"` with no `ref` or `rev`, plus `inputs.nixpkgs.follows = "nixpkgs-pre2611"`.
- Before this follow-up, `nix/flake.lock:93-99` held `locked.rev = "d619dbc4adb2407c5ad413b791acec5d8539819b"` (0.13.2), while `nix/flake.lock:101-105` showed `original` carrying only `owner`, `repo`, and `type`.
- Commit `71443e717597886adcce871117834d6b0bb78d9e` (2026-07-18, subject `fix(nix): pin Hunk for faster startup`) changed 2 files: `nix/flake.lock` (6 lines, the `lastModified`/`narHash`/`rev` triple) and the prior investigation document. It left `nix/flake.nix`, the `nixpkgs-pre2611` input, and `nix/hosts/m5-mbp/configuration.nix` untouched.

Reverting the pin is a single lock-node edit. No local file encodes a renderer or threading workaround:

- `nix/home/mp/darwin.nix:31-40` sets only `wrap_lines`, `theme`, `agent_notes`, `watch`, and `line_numbers`.
- `nix/home/mp/modules/fish/functions/hd.fish:44-58` injects only the `diff` subcommand and normalizes a leading `staged` to `--staged`; line 58 is `command hunk diff $hunk_args`.
- Repository-wide search for `OPENTUI`, `useThread`, `--renderer`, `--no-thread`, `TERM_PROGRAM`, and `broker` returns no active configuration. `HUNK_LOG` and `HUNK_STATUS` at `nix/scripts/verify-worktree-review-dx:38,113-114` are test-harness controls, not Hunk runtime variables.
- Neither `kitty/kitty.conf` nor `nix/home/mp/modules/kitty.nix` contains any Hunk- or renderer-specific setting.

No wrapper workaround is possible. PR 539's shipped application change is the deletion of `useThread: false` from `src/main.tsx`, restoring OpenTUI's platform default. The fix exposes no flag, environment variable, or config key, so nothing in `hd` or `~/.config/hunk/config.toml` can enable or disable it.

**Fragility not previously recorded:** because `original` carries no `rev`, the pin is undeclared and silently reversible. `nix/scripts/nix-ops:181` runs `nix flake update` under `update-inputs`, which would move Hunk to the latest `main` and drop the 0.13.2 pin without any diff to `nix/flake.nix`. The only signal would be the lock hash.

### F2. `nixpkgs-pre2611` has four consumers, and survives a Hunk bump twice over

The flake comment at `nix/flake.nix:17-23` states the input is "Kept for two consumers" and names only Hunk and the `terminal-notifier` overlay. The overlay actually imports three packages:

- `nix/hosts/m5-mbp/configuration.nix:36-42` inherits `terminal-notifier`, `whisper-cpp`, and `starship` from `nixpkgs-pre2611.legacyPackages.${prev.stdenv.hostPlatform.system}`.
- Stated failure mode at `nix/hosts/m5-mbp/configuration.nix:29-33`: "current unstable's cctools ld crashes (Trace/BPT trap 5) on every local link step on this machine, and the rev is too fresh for Hydra aarch64-darwin cache hits"
- All three are live selections: `nix/home/mp/packages/tier1.nix:28` (`terminal-notifier`), `nix/home/mp/packages/tier2.nix:65` (`whisper-cpp`), and `nix/home/mp/modules/starship.nix:4-9` (Starship via Home Manager).

The two dependency paths are disjoint in the flake wiring, which is what makes them independent:

- `nix/flake.nix:43` sends `nixpkgs-pre2611` to nix-darwin modules through `specialArgs`.
- `nix/flake.nix:48` sends only `hunk` to Home Manager through `home-manager.extraSpecialArgs`.
- `nix/home/mp/darwin.nix:1` accepts `{ hunk, ... }` and never references `nixpkgs-pre2611`.

Independently of the overlay, the Hunk-specific reason also survives a version bump: Hunk's own flake still enumerates `x86_64-darwin` at v0.17.6 (`flake.nix:24-27` upstream), which is the condition the comment names as incompatible with nixpkgs >= 26.11. Removing `inputs.nixpkgs.follows = "nixpkgs-pre2611"` isn't part of a pin removal.

### F3. Migration review is required, but it's a value-and-menu problem, not a schema problem

Every key set at `nix/home/mp/darwin.nix:33-38` is still parsed at v0.17.6 (`src/core/config.ts:231-245`): `wrap_lines`, `theme`, `watch`, `line_numbers`, and `agent_notes`. Parsing is per-key and lenient, with no strict unknown-key rejection. No key rename or removal affects this configuration.

The actual review items are:

1. **Theme value.** `ember` remains a legacy alias resolving to `dark-plus` at v0.17.6 (`src/ui/lib/shikiThemes.ts:71-77`). All four themes available in 0.13.2 are now aliases: `graphite` → `github-dark-default`, `midnight` → `github-dark-dimmed`, `paper` → `github-light-default`, `ember` → `dark-plus`. The silent appearance change documented against 0.17.0 persists in the newest release. The upstream default is now `github-dark-default` (`src/core/config.ts:322`).
2. **Completion menu.** `nix/home/mp/modules/fish/completions/hd.fish:80` completes `--theme` with exactly `graphite midnight paper ember`. All four now resolve to something else, and none is a currently bundled theme id. This menu is stale for any version at or after 0.16.
3. **Restoration path.** v0.17.6 adds a `[custom_theme]` table with `base`, `label`, and nested `syntax` colors (`src/core/config.ts:164-218`), validated against the bundled theme ids. This is the supported way to reproduce an Ember-like palette after the pin is lifted, replacing the "keep `theme = "ember"` while pinned" constraint.
4. **Keyboard.** The 0.17.0 change of Escape-to-quit to `q` has no local artifact to migrate: `nix/home/mp/modules/fish/functions/hd.fish:1-33` documents subcommands and examples but names no quit key, and the completions encode none. The exposure is muscle memory, not configuration.
5. **Pager.** The `hunk pager` subcommand still exists at v0.17.6 (`src/core/cli.ts:531-550`), so the `hdiff`/`hshow` aliases at `nix/home/mp/modules/git.nix:29-30` remain valid. `hunk-header-decoration-style` at `nix/home/mp/modules/git.nix:42` and `git/.gitconfig:43` is Delta terminology for a diff hunk, unrelated to this application.
6. **`watch = true` is set globally** at `nix/home/mp/darwin.nix:37`, and upstream issue 543, "Watch mode is very slow" (opened 2026-07-15), is open. This configuration is exposed to that path by default on every `hd` invocation.

New opt-in surface available since 0.13.2, not currently configured: `menu_bar`, `copy_decorations`, `transparent_background`, and `color_moved` (`src/core/config.ts:238-245`).

### F4. Local validation supplied the missing performance evidence

- Issue 534 is open with `comments = 0`, and `updated_at` equals `created_at` at `2026-07-13T08:58:08Z`. It carries no labels and no linked pull request. Its only timeline event is a cross-reference from PR 539 dated `2026-07-14T10:25:02Z`.
- PR 539 merged `2026-07-23T14:10:37Z` from branch `fix/kitty-startup-regression` as commit `a9b8694cd6bd1e0b7dfc77cf4e7a07e67677618a`, touching 2 files (+6/-1).
- The PR's own Validation section lists typecheck, lint, format, integration, and TTY-smoke runs, then states: "Final validation therefore requires comparing this branch against v0.17.0 in Kitty on macOS." The named baseline is v0.17.0, not the 0.13.2 baseline this repository measured.
- The PR also states: "This PR deliberately does not change code-column measurement or claim to explain the older v0.14 regression. It addresses the clear v0.17-era macOS threading regression independently." The locally measured boundary is 0.13.2 → 0.14.0 (1.21 s → 4.60 s). By its author's explicit scope, the shipped fix doesn't claim to address that boundary.
- On 2026-07-26, the reporter added the local A/B result to issue 534 and closed it as resolved for its original startup scope. The distinct large wrapped-diff failure and complete performance matrix are tracked in issue 600.

The release contains a plausible mechanism for part of the slowdown. The local validation below settles the original issue's practical outcome without claiming that PR 539 alone explains the original boundary.

**Newest release is v0.17.6, not v0.17.4.** Releases since the pin: v0.17.4 (`2026-07-23T20:45:55Z`) and v0.17.6 (`2026-07-25T01:59:13Z`). A `v0.17.5` tag exists with no published release; its notes say v0.17.6 "republish[es] the 0.17.5 application changes as 0.17.6 with downloadable binaries for every supported platform" instead. Two other v0.17.6 changes matter here. PR 586 speeds up terminal cell-width measurement for wide characters, including Chinese, Japanese, Korean, and emoji. PR 590 stops headless commands from loading OpenTUI's embedded native library, which addresses the temp-directory shared-library leak in open issue 556. Any evaluation should target v0.17.6, whose tag dereferences to commit `0d8dbfb8241a494b013ec5e0c2c6ebcbcf97c5b9` (v0.17.4 is `49c47660f18766bf544bfde75a7f879dc6fc2a65`).

### F5. Traced flow: Input to runtime

1. `nix/flake.nix:26-29` declares the `hunk` input without a revision, with nixpkgs following `nixpkgs-pre2611`.
2. Before this follow-up, `nix/flake.lock:86-105` resolved it to `d619dbc4adb2407c5ad413b791acec5d8539819b` (0.13.2). The completed change resolves it to v0.17.6 commit `0d8dbfb8241a494b013ec5e0c2c6ebcbcf97c5b9`.
3. `nix/flake.nix:48` forwards it via `home-manager.extraSpecialArgs = { inherit hunk; }`.
4. `nix/home/mp/darwin.nix:1,5` accepts `hunk` and imports `hunk.homeManagerModules.default`.
5. `nix/home/mp/darwin.nix:31-40` sets `programs.hunk.enable` plus `settings`, and the upstream module renders `~/.config/hunk/config.toml`.
6. Runtime entry points are `nix/home/mp/modules/fish/functions/hd.fish:58` (`command hunk diff $hunk_args`) and the opt-in `hunk pager` aliases at `nix/home/mp/modules/git.nix:29-30`.

Parallel and unrelated to Hunk: `nix/flake.nix:43` → `nix/hosts/m5-mbp/configuration.nix:1,36-42` overlay.

Upgrade chronology from git history:

| Author date | Commit | Effect |
| --- | --- | --- |
| 2026-07-12 | `9d2a1bd1a4eb59d03dfb364a5d2d29cc9e0e97bf` | Hunk `4f70481…` (0.12.0) → `059dd13…` (0.17.0); primary nixpkgs `456e8a9…` → `770b9bb…` |
| 2026-07-12 | `719b25ead354d8991c7cd584a07ef9b589f14bcb` | Introduced `nixpkgs-pre2611` at the former nixpkgs rev, pointed Hunk at it, added the three-package overlay; Hunk stayed at 0.17.0 |
| 2026-07-12 (committed 07-18) | `d5801d66317a58e245e0fdda089b429938d8dbf2` | Rebased replay of the same change; identical patch for these paths, different parent |
| 2026-07-18 | `71443e717597886adcce871117834d6b0bb78d9e` | Hunk `059dd13…` (0.17.0) → `d619dbc…` (0.13.2); nothing else |

The compatibility work and the performance pin were separate changes six days apart, which is the historical reason they're independently reversible.

### F6. Release attribution

PR 539's shipped diff is 2 files, +6/-1: a changeset file and the single-line deletion of `useThread: false` in `src/main.tsx`. It contains no code-width change. The ASCII and wide-character code-width optimization is a separate contribution, PR 586 by a different author, first released in v0.17.6, after v0.17.4. Treating the two as one shipment would attribute width-measurement gains to a release that doesn't contain them.

### F7. Local validation outcome

- Exact candidate: v0.17.6 tag commit `0d8dbfb8241a494b013ec5e0c2c6ebcbcf97c5b9`, store path `/nix/store/3r16z4l69zhhvqi8ivg9x6gaxrzv91dk-hunkdiff-0.17.6`, native arm64.
- Nix validation: `nix flake check --no-build --all-systems`, `statix check`, JSON parsing, and `darwin-rebuild build --flake .#m5-mbp` passed. `deadnix` reported only the existing unused overlay lambda arguments.
- Runtime validation: `hunk --version`, `hunk skill path`, `hunk diff --help`, `hunk pager --help`, current config parsing, and the five-scenario `verify-worktree-review-dx` harness passed.
- Native Kitty A/B: an isolated Kitty OS window used a clean detached worktree and `HEAD~5` diff. Each version used a private `HUNK_MCP_PORT`; the current `ember`, wrapping, watch, notes, and line-number settings remained unchanged. After one warm-up per version, 0.13.2 measured 395, 383, 391, and 389 ms; v0.17.6 measured 431, 374, 387, and 467 ms.
- The measurement polled Kitty's native screen text for the first complete file list and diff content. Screen sharing was disabled to avoid DRM playback interference, so this run doesn't provide pixel-level screenshots. The buffer result is sufficient to rule out the prior multi-second delay but doesn't compare theme appearance.
- Direct candidate entry points passed: `hd HEAD~5` reached the complete buffer in 467 ms. `git hdiff HEAD~5` and `git hshow HEAD` rendered their expected diff content through pager mode.
- The v0.17.6 lock update moved no input other than Hunk. Production-scale failure reversed that decision; the final lock restores exact v0.13.2 revision `d619dbc4adb2407c5ad413b791acec5d8539819b`.
- After rollback activation, `/etc/profiles/per-user/mp/bin/hunk` resolves to the validated v0.13.2 store path.
- A subsequent `hd main` review in `claude-toolkit` became unresponsive on a 141-file diff with 20,852 additions. Disabling global watch mode did not change the blank-screen result. Git produced the underlying diff in 0.02 seconds, which eliminates Git and the `hd` wrapper as causes.
- A process sample after 2 minutes 42 seconds found v0.17.6 idle on its event loop with a blank Kitty buffer and about 1 GB of memory in use.
- Production-scale matrix: v0.13.2 with wrapping rendered in 3.27 seconds and responded to navigation but used about 2 GB RSS; v0.17.6 with wrapping stayed blank; v0.17.6 with `--no-wrap` rendered in 0.63 seconds, responded to navigation, and used about 345 MB RSS; v0.17.6 with wrapping rendered a single 648-line file in 0.65 seconds.
- The literal `hd main --no-wrap` path on v0.17.6 rendered the full diff in 0.33 seconds, but disabling wrapping does not meet the normal review requirement.
- The final rollback candidate resolves `hd` to v0.13.2 with `watch = false` and `wrap_lines = true`. Before activation, the full diff rendered in 2.83 seconds, navigation updated the Kitty buffer, and the process used about 2.28 GB RSS. Evaluation, linting, generated-config inspection, and the full Darwin build passed. After activation, the literal `hd main` path rendered in 2.85 seconds and responded to navigation from the active profile.

## Investigation Log

### Prior local evidence

**Hypothesis:** The slowdown came from `hd` or local configuration.
**Findings:** The existing same-Kitty release bisect placed the regression at 0.13.2 to 0.14.0. The wrapper, theme alias, broker, architecture, repository, and terminal were eliminated.
**Evidence:** `docs/investigations/2026-07-13-hunk-hd-startup-regression.md`; commit `71443e717597886adcce871117834d6b0bb78d9e`.
**Conclusion:** The 0.13.2 lock is the performance workaround; `hd` is not.

### Upstream fix and release

**Hypothesis:** The PR linked from issue 534 proves the local regression is fixed.
**Findings:** PR 539 shipped in v0.17.4, but its validation requires a macOS/Kitty comparison against v0.17.0 and it disclaims the older v0.14 boundary.
**Evidence:** Issue 534, PR 539, v0.17.4, and the v0.17.6 tagged sources and release notes.
**Conclusion:** The intended v0.17-era threading fix shipped, and v0.17.6 no longer reproduces the original small-fixture slowdown. The production-scale wrapping failure is a separate issue.

### Local upgrade impact

**Hypothesis:** Removing the performance pin requires Nix or wrapper rewiring.
**Findings:** The pin is only the Hunk lock revision. The Hunk Home Manager keys still parse. `nixpkgs-pre2611` has independent Hunk and host-overlay consumers. Theme values, completions, watch behavior, and quit-key muscle memory need runtime review.
**Evidence:** `nix/flake.nix`, `nix/flake.lock`, `nix/home/mp/darwin.nix`, `nix/hosts/m5-mbp/configuration.nix`, `nix/home/mp/modules/fish/functions/hd.fish`, and `nix/home/mp/modules/fish/completions/hd.fish`.
**Conclusion:** Test a targeted v0.17.6 lock candidate while retaining the pre-26.11 nixpkgs follow and all current configuration.

### Candidate validation

**Hypothesis:** v0.17.6 restores practical startup performance without breaking local entry points.
**Findings:** The candidate and baseline produced overlapping native-Kitty buffer timings on the controlled fixture. Production-scale testing found a v0.17.6 failure when wrapping the full 141-file diff; disabling wrapping restores sub-second rendering.
**Evidence:** Exact timings and commands are recorded in F7. The lock diff changes only Hunk's `lastModified`, `narHash`, and `rev`.
**Conclusion:** Removing the version pin requires disabling a required review behavior. Restore the v0.13.2 pin, preserve wrapping, and disable global watch mode.

## Root Cause

The local 0.13.2 pin worked around an interactive startup regression first observed at Hunk 0.14.0. PR 539 restores OpenTUI's platform-default renderer threading on macOS, and v0.17.6 adds a separate width-measurement optimization. Those changes restore performance on the controlled fixture. A different production-scale failure remains: wrapping the full 141-file diff leaves v0.17.6 blank and idle, while disabling wrapping renders the same input in under a second. v0.13.2 renders the wrapped input but consumes about 2 GB, so the older release satisfies the required behavior at a substantial memory cost. Global watch mode compounds that cost and remains disabled.

## Recommendations

1. Keep the v0.13.2 lock. Retain `hunk.inputs.nixpkgs.follows = "nixpkgs-pre2611"` and the pre-26.11 input.
2. Keep wrapping enabled and global watch mode disabled. Use `hd --watch` only when live refresh is necessary.
3. Decide the appearance separately. Keeping `theme = "ember"` selects the `dark-plus` compatibility alias on v0.17.6; recreating the old Ember palette requires `[custom_theme]`.
4. Refresh the stale `--theme` completion menu after the theme decision.
5. Keep watch mode disabled by default while upstream issue 543 remains open. Use `hd --watch` only for smaller changesets that need live refresh.
6. Track the v0.17.6 wrapped large-diff failure in issue 600. Re-evaluate the pin when that issue has a candidate fix.

## Preventive Measures

- Declare intentional long-lived version pins in the flake input rather than relying only on a resolved lock entry, so broad input updates cannot silently remove them.
- Require exact release/revision inspection and a native-Kitty first-frame A/B check for future Hunk updates.
- Keep performance changes, theme/completion migrations, and nixpkgs compatibility changes as separate decisions with separate verification evidence.

## Accepted follow-ups

- **Appearance:** choose between the current `ember` compatibility alias (`dark-plus`) and a custom Ember-like theme after activation.
- **Completions:** refresh the curated `hd --theme` values after the appearance choice.
- **Visual evidence:** capture side-by-side screenshots later if pixel-level theme comparison is desired and screen sharing won't interfere with DRM playback.
