{
  description = "Match therapist availability to client schedules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/x86_64-linux";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    devshell.url = "github:numtide/devshell";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      devshell,
      treefmt-nix,
      pre-commit-hooks,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ devshell.overlays.default ];
        };
        treefmt = treefmt-nix.lib.evalModule pkgs {
          projectRootFile = ".git/config";
          programs = {
            nixfmt.enable = true;
            rustfmt.enable = true;
          };
        };
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            end-of-file-fixer.enable = true;
            mixed-line-endings.enable = true;
            trim-trailing-whitespace.enable = true;
            treefmt = {
              enable = true;
              package = treefmt.config.build.wrapper;
            };
          };
        };
        packages =
          with pkgs;
          [
            cargo
            rustc
          ]
          ++ pre-commit-check.enabledPackages;
      in
      {
        formatter = treefmt.config.build.wrapper;
        checks = {
          formatting = treefmt.config.build.check self;
          inherit pre-commit-check;
        };
        devShells.default = pkgs.devshell.mkShell {
          name = "alibot";
          inherit packages;
          devshell.startup."pre-commit-shellhook" = pkgs.lib.noDepEntry ''
            ${pre-commit-check.shellHook}
          '';
          devshell.startup."printpackages" = pkgs.lib.noDepEntry ''
            echo "[[ Packages ]]"
            echo "${builtins.concatStringsSep "\n" (builtins.map (p: p.name) packages)}"
            echo ""
          '';
        };
      }
    );
}
