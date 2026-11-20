# Cross-Platform Support

> Designing for portability between macOS and Linux.

This configuration is structured to support multiple platforms while keeping macOS as the primary focus.

---

## Current Scope

### Supported Now

| Platform | System | Status |
|----------|--------|--------|
| macOS (Apple Silicon) | `aarch64-darwin` | Primary target |
| macOS (Intel) | `x86_64-darwin` | Supported, not tested |

### Planned Future

| Platform | System | When |
|----------|--------|------|
| Linux (standalone HM) | `x86_64-linux` | When needed |
| NixOS | `x86_64-linux` | When needed |
| WSL | `x86_64-linux` | When needed |

---

## Architecture for Portability

### Layered Configuration

```
┌─────────────────────────────────────────────────────┐
│                    flake.nix                        │
│  Defines outputs for all platforms                  │
└─────────────────┬───────────────────────────────────┘
                  │
         ┌────────┴────────┐
         ▼                 ▼
┌─────────────────┐ ┌─────────────────┐
│ darwinConfigs   │ │ homeConfigs     │
│ (macOS hosts)   │ │ (Linux users)   │
└────────┬────────┘ └────────┬────────┘
         │                   │
         ▼                   ▼
┌─────────────────────────────────────────────────────┐
│                 home/mp/common.nix                  │
│  Cross-platform home settings (shell, git, etc.)   │
└─────────────────────────────────────────────────────┘
```

### What Goes Where

| Location | Purpose | Platform |
|----------|---------|----------|
| `home/mp/common.nix` | Shell, git, editor, CLI tools | All |
| `home/mp/darwin.nix` | macOS paths, behaviors | Darwin only |
| `home/mp/linux.nix` | Linux paths, systemd services | Linux only |
| `hosts/<hostname>/` | Machine-specific settings | Per-machine |
| `modules/home/*.nix` | Reusable home modules | All |
| `modules/darwin/*.nix` | nix-darwin modules | Darwin only |
| `modules/nixos/*.nix` | NixOS modules | NixOS only |

---

## Cross-Platform Home Config

### common.nix Structure

```nix
# home/mp/common.nix
{ config, pkgs, lib, ... }:
{
  # Packages available everywhere
  home.packages = with pkgs; [
    ripgrep
    fd
    bat
    fzf
    jq
  ];

  # Programs with cross-platform options
  programs.git = {
    enable = true;
    userName = "MP";
    userEmail = "markpaololibunao@gmail.com";
    delta.enable = true;
  };

  programs.fish = {
    enable = true;
    shellAbbrs = {
      v = "nvim";
      g = "git";
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
  };

  # Cross-platform config files
  xdg.configFile."nvim/init.lua".source = ./nvim/init.lua;
}
```

### darwin.nix Structure

```nix
# home/mp/darwin.nix
{ config, pkgs, lib, ... }:
{
  imports = [
    ./common.nix
    ../../modules/home/kitty.nix
  ];

  # macOS-specific packages
  home.packages = with pkgs; [
    # darwin-only tools if any
  ];

  # macOS-specific paths
  programs.fish.interactiveShellInit = ''
    # Homebrew (if used)
    if test -d /opt/homebrew/bin
      fish_add_path /opt/homebrew/bin
    end
  '';

  # macOS-specific config
  xdg.configFile."kitty/kitty.conf".text = ''
    shell /run/current-system/sw/bin/fish
    macos_option_as_alt yes
  '';
}
```

### linux.nix Structure (Future)

```nix
# home/mp/linux.nix
{ config, pkgs, lib, ... }:
{
  imports = [
    ./common.nix
  ];

  # Linux-specific packages
  home.packages = with pkgs; [
    # linux-only tools
  ];

  # Linux-specific paths
  programs.fish.interactiveShellInit = ''
    # Linux-specific init
  '';

  # Systemd user services (Linux only)
  # services.syncthing.enable = true;
}
```

---

## Platform Detection

### In Nix Expressions

```nix
{ config, pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
{
  home.packages = with pkgs; [
    # Common packages
    ripgrep
    fd
  ] ++ lib.optionals isDarwin [
    # macOS only
  ] ++ lib.optionals isLinux [
    # Linux only
  ];

  programs.fish.interactiveShellInit = ''
    # Common init
  '' + lib.optionalString isDarwin ''
    # macOS-specific
    fish_add_path /opt/homebrew/bin
  '' + lib.optionalString isLinux ''
    # Linux-specific
  '';
}
```

### Conditional Imports

```nix
# darwin.nix
{ config, pkgs, lib, ... }:
{
  imports = [
    ./common.nix
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    ../../modules/darwin/aerospace.nix
    ../../modules/darwin/karabiner.nix
  ];
}
```

---

## Future: Adding Linux Support

### Step 1: Create Linux Home Config

```nix
# home/mp/linux.nix
{ config, pkgs, ... }:
{
  imports = [ ./common.nix ];

  home.username = "mp";
  home.homeDirectory = "/home/mp";
  home.stateVersion = "24.11";

  # Linux-specific settings
}
```

### Step 2: Add to flake.nix

```nix
# flake.nix
{
  outputs = { self, nixpkgs, home-manager, darwin, ... }: {
    # Existing darwin configs
    darwinConfigurations."macbook" = darwin.lib.darwinSystem { ... };

    # New: standalone home-manager for Linux
    homeConfigurations."mp@linux-host" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [ ./home/mp/linux.nix ];
    };

    # Future: NixOS configuration
    # nixosConfigurations."linux-host" = nixpkgs.lib.nixosSystem { ... };
  };
}
```

### Step 3: Apply on Linux

```bash
# Standalone home-manager on Linux
home-manager switch --flake .#mp@linux-host
```

---

## Platform-Specific Considerations

### Paths

| Item | macOS | Linux |
|------|-------|-------|
| Homebrew | `/opt/homebrew` | N/A |
| Fish shell | `/run/current-system/sw/bin/fish` | `/run/current-system/sw/bin/fish` (NixOS) or `/home/user/.nix-profile/bin/fish` |
| Config dir | `~/Library/...` or `~/.config/` | `~/.config/` |

### Services

| Feature | macOS (nix-darwin) | Linux (NixOS/systemd) |
|---------|-------------------|----------------------|
| User services | launchd | systemd --user |
| System services | launchd | systemd |
| Auto-start | launchd plist | systemd enable |

### Window Management

| Tool | macOS | Linux |
|------|-------|-------|
| AeroSpace | Supported | N/A |
| i3/Sway | N/A | Supported |

---

## Testing Cross-Platform

### Verify Evaluation

```bash
# Check all outputs evaluate
nix flake check ./nix --no-build --all-systems

# Evaluate the Darwin system without building it
nix eval --raw ./nix#darwinConfigurations.m5-mbp.system.drvPath
```

### Continuous Integration

[`.github/workflows/nix-check.yml`](../../.github/workflows/nix-check.yml) runs one job on `ubuntu-latest`:

- the shell tests from `nix/tests/` that the workflow lists
- `nix eval` of the `m5-mbp` Darwin system's derivation path
- `nix flake check --no-build --all-systems`

Import from derivation is off, so evaluation never needs a macOS builder. CI doesn't build or activate the system. Build it on the Mac with `nix/scripts/nix-verify`.

---

## Best Practices

### DO

- Keep `common.nix` truly cross-platform
- Use `lib.optionals` for conditional packages
- Test evaluation on all target systems
- Document platform-specific behaviors

### DON'T

- Hardcode macOS paths in common config
- Use darwin-only options in common modules
- Assume Homebrew exists on all machines
- Mix NixOS and standalone HM concepts in same file
