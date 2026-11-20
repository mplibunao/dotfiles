{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Package managers
    bun # JS runtime + package manager + toolkit
    # pnpm is intentionally omitted: repo-local Corepack pins set the pnpm
    # version, while Nix owns mise (below) and shell bootstrap.
    # yarn via Corepack (mise-managed Node) - Nix yarn bundles its own Node version
    uv # Python package manager (fast, used by ccnotify hooks)

    # Image processing
    vips # Image processing library (required for WizyVision sharp)

    # PDF tooling
    poppler-utils # pdftoppm/pdftotext for rendering and extracting PDFs (enables Read-tool PDF support)

    # Compression
    zstd # Zstandard compression for RepoPrompt CE local release archives

    # Infrastructure
    terraform # Infrastructure as Code (BSL license)
    terraform-ls # Terraform LSP for editor integration
    gopls # Go LSP for editor/agent integration
    sentry-cli # Sentry release and sourcemap upload CLI
    tflint # Terraform linter
    # checkov intentionally not installed globally: wizyemm-infra provenance
    # checks require its own hash-locked venv checkov and reject a Nix/system
    # one, and the nixpkgs package pulls CVE-flagged python-ecdsa.
    conftest # OPA/Rego policy checks against Terraform plans
    gitleaks # Secret scanner; repo commit/push preflights (e.g. repoprompt-ce) invoke it by name
    mise # Polyglot version manager (per-repo .tool-versions)
    cloudflared # Cloudflare tunnel (local demos via demo.<domain>)

    # Python tooling
    pipx # Install Python CLI tools in isolated envs
    (google-cloud-sdk.withExtraComponents [
      google-cloud-sdk.components.app-engine-java
      google-cloud-sdk.components.config-connector
    ]) # GCP CLI + App Engine Java + Config Connector (bulk-export)

    # Go tooling
    go # Go toolchain: gofmt, go vet, go test (used by nvim-lazy harness checks)
    gotestsum # Human-friendly go test runner (used by neotest-golang)

    # JVM
    (pkgs.callPackage ../../../packages/maven { }) # Build tool for WizyEMM backend (Kotlin/JVM); version pinned in the package

    # Database
    postgresql # PostgreSQL client and libs

    # TUI Tools
    lazydocker # Docker TUI

    # Code search / rewrite
    ast-grep # Structural search/rewriter

    # Prose linting
    vale # Configurable prose linter (global config managed in vale.nix)

    # Shell linting
    shellcheck # Shell script linter (used by claude-toolkit verify:shell + pre-commit)

    # File watching
    fswatch # File change monitor (uses macOS FSEvents)

    # Media / audio
    whisper-cpp # whisper.cpp CLI (provides `whisper-cli`) for local audio transcription

    # Native build tooling
    cmake # CMake 3.28+; required by whisper.cpp build-xcframework.sh for the voiceink-update from-source VoiceInk build
  ];
}
