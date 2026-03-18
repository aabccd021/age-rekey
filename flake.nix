{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }:
    let
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      linkFarmAll =
        system: flake:
        lib.pipe flake [
          (lib.filterAttrs (
            name: output:
            !lib.elem name [ "checks" ]
            && output ? ${system}
            && builtins.isAttrs output.${system}
            && !(output.${system} ? type)
          ))
          (lib.mapAttrsToList (
            outputName: output:
            lib.mapAttrsToList (name: drv: {
              name = "${outputName}-${name}";
              path = drv;
            }) output.${system}
          ))
          lib.concatLists
          (pkgs.linkFarm "all")
        ];

      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        programs.deadnix.enable = true;
        programs.nixfmt.enable = true;
        programs.shfmt.enable = true;
        programs.shellcheck.enable = true;
      };

      packages = {
        default = pkgs.writeShellApplication {
          name = "age-rekey";
          runtimeInputs = with pkgs; [
            age
            coreutils # base64, sha256sum, cut, head, tr, mktemp
            gnugrep # grep
            unixtools.xxd # xxd for hex conversion
          ];
          text = builtins.readFile ./age-rekey.sh;
        };
        formatting = treefmtEval.config.build.check self;
        test-check-consistent = pkgs.runCommand "test-check-consistent" {
          nativeBuildInputs = [
            packages.default
            pkgs.age
            pkgs.openssh
          ];
        } (builtins.readFile ./test-check-consistent.sh);
        test-check-mismatch = pkgs.runCommand "test-check-mismatch" {
          nativeBuildInputs = [
            packages.default
            pkgs.age
            pkgs.openssh
          ];
        } (builtins.readFile ./test-check-mismatch.sh);
        test-rekey-add-recipient = pkgs.runCommand "test-rekey-add-recipient" {
          nativeBuildInputs = [
            packages.default
            pkgs.age
            pkgs.openssh
          ];
        } (builtins.readFile ./test-rekey-add-recipient.sh);
        test-rekey-remove-recipient = pkgs.runCommand "test-rekey-remove-recipient" {
          nativeBuildInputs = [
            packages.default
            pkgs.age
            pkgs.openssh
          ];
        } (builtins.readFile ./test-rekey-remove-recipient.sh);
        test-rekey-armor = pkgs.runCommand "test-rekey-armor" {
          nativeBuildInputs = [
            packages.default
            pkgs.age
            pkgs.openssh
          ];
        } (builtins.readFile ./test-rekey-armor.sh);
        test-check-different-key = pkgs.runCommand "test-check-different-key" {
          nativeBuildInputs = [
            packages.default
            pkgs.age
            pkgs.openssh
          ];
        } (builtins.readFile ./test-check-different-key.sh);
      };

    in
    {
      packages.x86_64-linux = packages;
      formatter.x86_64-linux = treefmtEval.config.build.wrapper;
      checks.x86_64-linux.all = linkFarmAll "x86_64-linux" self;
    };
}
