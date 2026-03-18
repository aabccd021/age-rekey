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
      lib = nixpkgs.lib;

      linkFarmAll =
        flake: outputs:
        let
          toEntries =
            outputName:
            let
              output = flake.${outputName}.x86_64-linux;
              asAttrset = if lib.isDerivation output then { default = output; } else output;
            in
            lib.mapAttrsToList (name: drv: {
              name = "${outputName}-${name}";
              path = drv;
            }) asAttrset;
        in
        pkgs.linkFarm "all" (lib.concatMap toEntries outputs);

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

    in
    {
      packages.x86_64-linux = packages;
      formatter.x86_64-linux = formatter;
      checks.x86_64-linux.all = linkFarmAll self [
        "packages"
        "formatter"
      ];
    };
}
