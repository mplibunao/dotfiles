# Kokoro TTS Home Manager Module
#
# Provides local AI-powered text-to-speech using the Kokoro-82M model.
# Uses ONNX runtime for fast inference on Apple Silicon.
#
# Usage in your darwin.nix:
#   mp.kokoroTts.enable = true;
#
# This creates a `kokoro-say` wrapper script accessible at:
#   ~/.nix-profile/bin/kokoro-say
#
# The daemon is managed via LaunchAgent when enabled.
#
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mp.kokoroTts;

  # Python environment with required packages
  pythonEnv = pkgs.python312.withPackages (ps: [
    ps.onnxruntime
    ps.ttstokenizer
    ps.soundfile
    ps.numpy
  ]);

  # NLTK data required by ttstokenizer (fetched directly, no network during build)
  nltkTagger = pkgs.fetchzip {
    url = "https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/taggers/averaged_perceptron_tagger_eng.zip";
    sha256 = "sha256-BrGa4NeDVdFpTyVLsB4+5i5/N998HGqNUtgEKNQqvUo=";
    stripRoot = false;
  };

  nltkCmudict = pkgs.fetchzip {
    url = "https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/cmudict.zip";
    sha256 = "sha256-iSSqqygYwAuA4d0721Z/ZeWTtgkd4bKircAfWQ3pYXU=";
    stripRoot = false;
  };

  # Combined NLTK data directory
  nltkData = pkgs.symlinkJoin {
    name = "nltk-data-kokoro";
    paths = [ ];
    postBuild = ''
      mkdir -p $out/taggers $out/corpora
      ln -s ${nltkTagger}/averaged_perceptron_tagger_eng $out/taggers/
      ln -s ${nltkCmudict}/cmudict $out/corpora/
    '';
  };

  # Kokoro ONNX model from NeuML/kokoro-base-onnx (~345 MB)
  kokoroModel = pkgs.fetchurl {
    url = "https://huggingface.co/NeuML/kokoro-base-onnx/resolve/main/model.onnx";
    sha256 = "0jbyypnwklj959x0v2ll4dcr5wljfvn5l7ag1fvfkzkygx2l5vzb";
    name = "kokoro-82m.onnx";
  };

  # Voice embeddings JSON
  kokoroVoices = pkgs.fetchurl {
    url = "https://huggingface.co/NeuML/kokoro-base-onnx/resolve/main/voices.json";
    sha256 = "01fz12x4z3c5s79akl9ra5j19z0sk6gdki960yck1jrkhc76f96w";
    name = "kokoro-voices.json";
  };

  # Kokoro worker script (daemon mode, stdin/stdout NDJSON)
  kokoroWorkerScript = pkgs.writeText "kokoro-worker.py" (builtins.readFile ./kokoro-worker.py);

  kokoroWorker = pkgs.writeShellApplication {
    name = "kokoro-worker";
    runtimeInputs = [ pythonEnv ];
    text = ''
      export NLTK_DATA="${nltkData}"
      export KOKORO_MODEL_PATH="${kokoroModel}"
      export KOKORO_VOICES_PATH="${kokoroVoices}"
      exec "${pythonEnv}/bin/python" "${kokoroWorkerScript}" "$@"
    '';
  };

  # kokoro-say wrapper script (daemon client)
  kokoroSay = pkgs.writeShellApplication {
    name = "kokoro-say";
    runtimeInputs = [
      pkgs.jq
      pkgs.netcat
    ];
    text = ''
      set -euo pipefail

      SOCKET="''${CCCTL_KOKORO_SOCKET:-$HOME/.claude/ccctl/tts/kokoro.sock}"
      if [[ ! -S "$SOCKET" ]]; then
        echo "Error: Kokoro daemon not running (socket missing)" >&2
        exit 1
      fi

      TEXT="$*"
      if [[ -z "$TEXT" ]]; then
        echo "Usage: kokoro-say <text>" >&2
        exit 1
      fi

      REQUEST=$(jq -nc --arg text "$TEXT" '{v:1,clientId:"cli",type:"speak",text:$text}')
      RESPONSE=$(echo "$REQUEST" | nc -U "$SOCKET" 2>/dev/null || echo '{"ok":false}')
      echo "$RESPONSE" | jq -e '.ok == true' >/dev/null 2>&1 || {
        echo "Error: Kokoro daemon rejected request" >&2
        exit 1
      }
    '';
  };

  ccctlScript = cfg.daemon.ccctlPath;
  daemonSocket = "${config.home.homeDirectory}/.claude/ccctl/tts/kokoro.sock";
  daemonTmpDir = "${config.home.homeDirectory}/.claude/ccctl/tts/tmp";
  daemonLog = "${config.home.homeDirectory}/.claude/ccctl/tts/daemon.log";
  launchAgentPlist = pkgs.writeText "com.mp.ccctl.ttsd.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>com.mp.ccctl.ttsd</string>
        <key>ProgramArguments</key>
        <array>
          <string>${ccctlScript}</string>
          <string>ttsd</string>
          <string>run</string>
          <string>--check-deps</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <dict>
          <key>SuccessfulExit</key>
          <false/>
        </dict>
        <key>ThrottleInterval</key>
        <integer>10</integer>
        <key>EnvironmentVariables</key>
        <dict>
          <key>CCCTL_KOKORO_WORKER_BIN</key>
          <string>${kokoroWorker}/bin/kokoro-worker</string>
          <key>CCCTL_KOKORO_SOCKET</key>
          <string>${daemonSocket}</string>
          <key>CCCTL_KOKORO_TMP_DIR</key>
          <string>${daemonTmpDir}</string>
          <key>CCCTL_KOKORO_COREML</key>
          <string>${cfg.coreml.mode}</string>
          <key>PATH</key>
          <string>${lib.makeBinPath [ pkgs.bun ]}:/usr/bin:/bin</string>
        </dict>
        <key>StandardOutPath</key>
        <string>${daemonLog}</string>
        <key>StandardErrorPath</key>
        <string>${daemonLog}</string>
      </dict>
    </plist>
  '';

in
{
  options.mp.kokoroTts = {
    enable = lib.mkEnableOption "Kokoro TTS (local AI text-to-speech)";

    daemon = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to install and auto-start the Kokoro daemon via LaunchAgent.";
      };

      ccctlPath = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.claude/scripts/ccctl";
        description = "Absolute path to ccctl wrapper script (created by claude-toolkit/setup.sh).";
      };
    };

    coreml = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "auto"
          "on"
          "off"
        ];
        default = "auto";
        description = "CoreML execution provider mode for kokoro-worker (auto/on/off).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.daemon.ccctlPath;
        message = "mp.kokoroTts.daemon.ccctlPath must be an absolute path.";
      }
    ];

    # Add kokoro-say + kokoro-worker to path
    home.packages = [
      kokoroSay
      kokoroWorker
    ];

    home.file = lib.mkIf cfg.daemon.enable {
      "Library/LaunchAgents/com.mp.ccctl.ttsd.plist" = {
        source = launchAgentPlist;
      };
    };

    # Warn about storage requirements
    warnings = [
      "mp.kokoroTts: Adds ~1.85 GiB to Nix store (python312 + onnxruntime + ~345MB model)"
    ];
  };
}
