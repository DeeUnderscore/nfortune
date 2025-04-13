{
  description = "fortune, but in Nim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      eachFlakeSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      nfortuneDeriv = (
        {
          lib,
          buildNimPackage,
          docutils,
        }:
        buildNimPackage {
          pname = "nfortune";
          version = "1.0.2";

          src = lib.sources.cleanSource ./.;

          lockFile = ./nix-lock.json;

          nativeBuildInputs = [
            docutils
          ];

          postBuild = ''
            rst2man doc/nfortune.6.rst > doc/nfortune.6
          '';

          postInstall = ''
            install -Dt $out/share/man/man6 doc/nfortune.6
          '';
        }
      );
    in
    {
      packages = eachFlakeSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          nfortune = pkgs.callPackage nfortuneDeriv { };
          default = nfortune;
        }
      );

      apps = eachFlakeSystem (system: rec {
        nfortune = {
          type = "app";
          program = "${self.packages.${system}.nfortune}/bin/nfortune";
        };
        default = nfortune;
      });

      overlays.default = (
        final: prev: {
          nfortune = final.callPackage nfortuneDeriv { };
        }
      );

      overlay = self.overlays.default;
    };
}
