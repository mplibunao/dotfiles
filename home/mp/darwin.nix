{ hunk, ... }:

{
  imports = [
    hunk.homeManagerModules.default
    ./common.nix
    ./package-tiers/tier1.nix
    ./package-tiers/tier2.nix
    ../../modules/fish
    ../../modules/git
    ../../modules/starship
    ../../modules/neovim
    ../../modules/kitty
    ../../modules/node
    ../../modules/llm-tools
    ../../modules/direnv
    ../../modules/bat
    ../../modules/nix-ops-tools
    ../../modules/whisper-model
    ../../modules/karabiner
    ../../modules/aerospace
    ../../modules/ssh
    ../../modules/kokoro-tts
    ../../modules/cloudflared
    ../../modules/surf-openai-gateway
    ../../modules/executor
    ../../modules/cli-proxy/api.nix
    ../../modules/cli-proxy/dashboard.nix
    ../../modules/vale
    ../../modules/codexbar
    ../../modules/tinycast
  ];

  # macOS-specific Home Manager configuration

  programs.hunk = {
    enable = true;
    settings = {
      # Prefer readable prose diffs in normal review flows.
      wrap_lines = true;
      theme = "catppuccin-mocha";
      agent_notes = true;
      # Auto-refresh can overwhelm large agent-authored diffs; opt in with hd --watch.
      watch = false;
      line_numbers = true;
    };
  };

  mp = {
    # Kokoro TTS - local AI text-to-speech via ONNX
    # TODO: Re-enable once the current unstable nixpkgs pin can link native
    # packages on this machine (cctools ld Trace/BPT trap 5) or Hydra caches
    # the pinned rev — its onnxruntime/python stack must compile locally today
    # and fails at the link step.
    kokoroTts.enable = false;

    # Cloudflare named tunnel config (manual run lifecycle)
    cloudflared.enable = true;

    # surf OpenAI gateway: RepoPrompt's oracle provider, kept alive by launchd
    surfOpenaiGateway.enable = true;

    # Executor: the MCP gateway service every client's `executor mcp` bridges to
    executor.enable = true;

    # CLIProxyAPI on 127.0.0.1:8317. The usage dashboard listens on 8788;
    # surfOpenaiGateway keeps 8787. See nix/docs/runbooks/cli-proxy-api.md.
    cliProxyApi.enable = true;
    # The live dashboard runs from its own checkout of main and reads its
    # feature switches, such as soonest-reset routing, from that checkout's
    # config/production.env.
    cliProxyDashboard.enable = true;

    # CodexBar counts RepoPrompt CE's Codex sessions (see ADR-022)
    codexbar.enable = true;
  };
}
