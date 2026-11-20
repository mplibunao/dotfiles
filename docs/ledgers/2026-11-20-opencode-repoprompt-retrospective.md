# Retrospective ledger: OpenCode for RepoPrompt through Nix

Request: none · Plan: `docs/exec-plans/completed/opencode-repoprompt-nix-2026-08-22.md` in `mplibunao/dotfiles-private`

RepoPrompt CE can run OpenCode as an agent over the Agent Client Protocol (ACP). This work, planned on 2026-08-22, committed on 2026-08-25, and merged on 2026-08-26, installed a pinned OpenCode from Nix and gave the RepoPrompt app a fixed path to find it. Credentials and provider choices stayed outside Nix.

| Item | Outcome |
|------|---------|
| 1. Pinned OpenCode package and discovery path | done |
| 2. Activation | done |
| 3. RepoPrompt connection and agent runs | partial |
| 4. Model catalog, pricing, and privacy review | partial |

## 1. Pinned OpenCode package and discovery path

- Decision: [ADR-021](../../nix/docs/decisions/021-opencode-upstream-flake-for-repoprompt-acp.md) records the choices: the tagged upstream OpenCode flake with its own lock graph, Tier 1 membership, a Home Manager-owned `~/.local/bin/opencode` link for the GUI, no persistent OpenCode MCP entry, and authentication left to `opencode auth`. [The runbook](../../nix/docs/runbooks/opencode-repoprompt.md) covers onboarding and upgrades. Source: the plan.
- Evidence: `feat(nix): add OpenCode for RepoPrompt` (2026-08-25) changed `nix/flake.nix`, `nix/flake.lock`, `nix/home/mp/packages/tier1.nix`, and `nix/home/mp/modules/llm-tools.nix`, pinning OpenCode `v1.18.21`. The plan records that `nix flake check --no-build --all-systems`, `nixfmt --check`, `deadnix`, and `darwin-rebuild build` passed, and that `statix` exited 1 on a repeated-key warning that predated the change.
- Evidence: later changes replaced parts of this setup. [ADR-023](../../nix/docs/decisions/023-opencode-cursor-client-config-ownership.md) moved OpenCode's client config to exact-file ownership, [ADR-025](../../nix/docs/decisions/025-opencode-node-modules-hash-override.md) added a local `node_modules` hash override, and `feat(nix): install OpenCode 2.2.5 from its release tag` (merged 2026-11-03) replaced the 1.18.21 pin.

## 2. Activation

- Evidence (recorded in the plan, 2026-08-25): a switch dry-run without root exited 1 before showing a preview, then the activation was approved and run. Afterwards `opencode` reported `1.18.21`, `~/.local/bin/opencode` resolved to the Nix package, no other OpenCode executable was on the path, and `opencode acp --help` passed with both the normal and a minimal `PATH`. `opencode auth list` showed one OpenCode Zen credential, stored with mode 0600. No secret was read.

## 3. RepoPrompt connection and agent runs

- Evidence (recorded in the plan, 2026-08-25): RepoPrompt CE 1.3.0 connected to the OpenCode provider and stored its model in RepoPrompt's model registry, and the `design` role resolved to it. A read-only prompt through that role succeeded, as did polling, a steer in the same session, cancelling a disposable session, and a direct run with the model ID built from the registry's provider and model values. No permission prompt appeared, and the sessions didn't change any files.
- Deferred: three acceptance criteria remained open and are not verified. RepoPrompt's `agent_manage.list_agents` didn't list the `openCode:` model ID as text, no run used a verbatim discovered ID, and the access mode the runs used wasn't established.

## 4. Model catalog, pricing, and privacy review

- Evidence (recorded in the plan, reviewed 2026-08-25): OpenCode Zen's documentation listed Ox Alpha Free (`opencode/x-preview-f-free`) as free for a limited time, with US hosting, zero retention, and no training on submitted data for that model. These terms were time-limited and specific to that model.
- Deferred: authoritative usage limits or quotas for Ox Alpha Free weren't established: not verified. The word "Unlimited" in RepoPrompt's model name isn't evidence of the provider's limits.
