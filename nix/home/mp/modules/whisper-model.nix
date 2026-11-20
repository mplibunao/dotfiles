{ lib, pkgs, ... }:

let
  modelName = "ggml-large-v3-turbo.bin";
  cacheRelativePath = ".cache/whisper/${modelName}";
  largeV3TurboModel = pkgs.fetchurl {
    name = modelName;
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/6034871ec87c84e342efab769d4c5c06cd126db3/ggml-large-v3-turbo.bin";
    hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
  };
in
{
  # m5-mbp sets home-manager.backupFileExtension = "backup". Run before
  # checkLinkTargets so that global backup behavior cannot silently move aside a
  # regular cache file. Any manual move/removal requires separate exact-path
  # approval; activation accepts only absence or the exact expected store link.
  home.activation.whisperModelDestinationPreflight = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    destination="$HOME/${cacheRelativePath}"
    expected=${lib.escapeShellArg (toString largeV3TurboModel)}

    if [ -L "$destination" ]; then
      resolved="$(${pkgs.coreutils}/bin/readlink -f -- "$destination" 2>/dev/null || true)"
      if [ "$resolved" != "$expected" ]; then
        echo "whisper-model: refusing unexpected cache symlink: $destination" >&2
        echo "  resolved: ''${resolved:-<unresolved>}" >&2
        echo "  expected: $expected" >&2
        exit 1
      fi
    elif [ -e "$destination" ]; then
      echo "whisper-model: refusing occupied cache destination: $destination" >&2
      echo "  Home Manager backupFileExtension must not bypass explicit migration approval." >&2
      echo "  Obtain separate approval to move or remove this exact path, then retry." >&2
      exit 1
    fi
  '';

  # Store-managed on purpose: the model is immutable, reproducible state rather
  # than an app-owned or frequently edited cache entry. Never force replacement.
  home.file."${cacheRelativePath}".source = largeV3TurboModel;
}
