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
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        programs.deadnix.enable = true;
        programs.nixfmt.enable = true;
        programs.shfmt.enable = true;
        programs.shellcheck.enable = true;
      };

      formatter = treefmtEval.config.build.wrapper;

      packages = {
        default = pkgs.writeShellApplication {
          name = "age-rekey";
          runtimeInputs = [ ];
          text = builtins.readFile ./age-rekey.sh;
        };
        formatting = treefmtEval.config.build.check self;
      };

      checks = {
        all = pkgs.linkFarm "all" (
          nixpkgs.lib.mapAttrsToList (name: drv: {
            name = "packages-${name}";
            path = drv;
          }) packages
          ++ [
            {
              name = "formatter-treefmt";
              path = formatter;
            }
          ]
        );
      };
    in
    {
      packages.x86_64-linux = packages;
      checks.x86_64-linux = checks;
      formatter.x86_64-linux = formatter;
    };
}
