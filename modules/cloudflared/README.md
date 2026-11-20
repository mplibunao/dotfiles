# Cloudflared named tunnel (`demo`)

This directory stores the repo-managed non-secret `cloudflared` config that Home Manager symlinks to `~/.cloudflared/config.yml`.

## Why no LaunchAgent

Manual lifecycle is intentional (principle of least privilege). This tunnel is for demos and should run only when needed, not always-on in the background.

## Manual bootstrap (required once)

`cloudflared` is already in Tier 2 packages. After your first `darwin-rebuild switch`, run:

```fish
cloudflared tunnel login
cloudflared tunnel create demo
cloudflared tunnel route dns demo demo.mplibunao.com
```

Expected local artifacts:

- `~/.cloudflared/cert.pem`
- `~/.cloudflared/<tunnel-uuid>.json`

Then replace `REPLACE_WITH_TUNNEL_UUID` in `config.yml` with the UUID from `cloudflared tunnel create demo`.

## Runtime usage (manual)

```fish
cloudflared tunnel run demo
```

Stop with `Ctrl-C`.

## Operations

Check tunnel status:

```fish
cloudflared tunnel list
cloudflared tunnel info demo
```

Add a second route (new hostname/new local port):

1. Edit `config.yml` ingress and add the new `hostname`/`service` block before the catch-all `http_status:404` rule.
2. Run DNS route creation for the new hostname:

```fish
cloudflared tunnel route dns demo <new-hostname>
```

3. Restart `cloudflared` to pick up config changes. No Nix rebuild is needed.

Live config reload without full restart: send `SIGHUP` to the running process.

```fish
kill -HUP (pgrep cloudflared)
```

Shell-agnostic equivalent: `kill -HUP $(pgrep cloudflared)`.

## Recovery

If `cert.pem` is lost or expired:

```fish
cloudflared tunnel login
```

Existing tunnels remain valid.

If `<uuid>.json` credentials are lost but `cert.pem` is still present:

```fish
cloudflared tunnel token --cred-file ~/.cloudflared/<uuid>.json demo
```

Full reset (new tunnel identity):

```fish
cloudflared tunnel delete demo
```

Then run bootstrap again (`login` → `create` → `route dns`). This generates a new UUID; update `config.yml` accordingly.

## Dashboard context

This setup is locally managed: source-of-truth is this repo’s `config.yml` plus CLI operations. The tunnel appears in Zero Trust → Networks → Tunnels for visibility. Do not switch it to remotely-managed mode in the dashboard, or repo state will drift from runtime state.

## Troubleshooting

- DNS may take ~30s–5min after `cloudflared tunnel route dns ...`. Verify with `dig demo.mplibunao.com +short`.
- 502 at tunnel hostname usually means the backing local service (configured port) is not running.
- `cloudflared tunnel run demo` connection/refused errors often mean `config.yml` UUID does not match an existing tunnel; verify with `cloudflared tunnel list`.
- If browser shows Cloudflare error page instead of your app, `cloudflared` is likely not running; start `cloudflared tunnel run demo`.

## Secret boundary

Never commit:

- `~/.cloudflared/cert.pem`
- `~/.cloudflared/<tunnel-uuid>.json`

Only `config.yml` in this folder is committed.
