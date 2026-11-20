{
  stdenv,
  opencodeFlake,
}:

let
  inherit (stdenv.hostPlatform) system;
  upstream = opencodeFlake.packages.${system}.opencode;

  # An OpenCode release tag's nix/hashes.json can hold the node_modules hash of
  # an earlier dependency tree, which makes the tag's own build fail with a hash
  # mismatch. Each entry is the hash Nix reported for the tag pinned
  # in flake.nix (ADR-025), so it must be replaced or removed whenever that tag
  # changes.
  nodeModulesHashes = {
    aarch64-darwin = "sha256-bp2jsa4iX5jX4O3vWQC9TRSwsAtnkzXX86O90NaJdq8=";
  };
in
if nodeModulesHashes ? ${system} then
  upstream.override (prev: {
    node_modules = prev.node_modules.override { hash = nodeModulesHashes.${system}; };
  })
else
  upstream
