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
          runtimeInputs = [ ];
          text = builtins.readFile ./age-rekey.sh;
        };
        formatting = treefmtEval.config.build.check self;
      };

    in
    {
      packages.x86_64-linux = packages;
      formatter.x86_64-linux = treefmtEval.config.build.wrapper;
      checks.x86_64-linux.all = linkFarmAll "x86_64-linux" self;
    };
}
