{
  description = "MP's nix-darwin + Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    darwin = {
      url = "github:nix-darwin/nix-darwin"; # master has system.primaryUser
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager"; # master for nixpkgs-unstable
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Last pre-26.11 nixpkgs this flake used. Kept for two consumers that
    # break on current unstable: hunk (its flake-parts/treefmt outputs
    # evaluate for x86_64-darwin, which nixpkgs >= 26.11 rejects outright)
    # and the terminal-notifier overlay (cctools ld crashes linking it on
    # fresh unstable revs Hydra has not cached yet).
    # TODO: Drop once hunk upstream stops evaluating x86_64-darwin and
    # terminal-notifier builds (or is cached) on current unstable.
    nixpkgs-pre2611.url = "github:NixOS/nixpkgs/456e8a9468b9d46bd8c9524425026c00745bc4d2";

    hunk = {
      # Pin the wrapped large-diff fix until an upstream release contains it.
      url = "github:mplibunao/hunk/bugfix/wrapped-large-diff";
      inputs.nixpkgs.follows = "nixpkgs-pre2611";
    };

    opencode.url = "github:anomalyco/opencode/v2.2.5";
  };

  outputs =
    {
      darwin,
      home-manager,
      hunk,
      nixpkgs,
      nixpkgs-pre2611,
      opencode,
      ...
    }:
    {
      # The Mac builds the aarch64-darwin archive. The Linux output is the
      # same expression for the linux_amd64 archive, so the package can be
      # built and run off the Mac. cli-proxy-api-aarch64-darwin unpacks the
      # Mac archive with a Linux stdenv when no Darwin builder is available.
      packages = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          cli-proxy-api = pkgs.callPackage ./packages/cli-proxy-api { };
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          cli-proxy-api-aarch64-darwin = pkgs.callPackage ./packages/cli-proxy-api {
            targetSystem = "aarch64-darwin";
          };
        }
      );

      darwinConfigurations."m5-mbp" = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit nixpkgs-pre2611; };
        modules = [
          ./hosts/m5-mbp/configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.extraSpecialArgs = { inherit hunk opencode; };
          }
        ];
      };
    };
}
