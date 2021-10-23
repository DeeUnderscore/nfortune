{
  description = "fortune, but in Nim";

  inputs = {
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, utils, nixpkgs, nimble }:
  let
    nfortuneDeriv = ({pkgs}: with pkgs; stdenv.mkDerivation {
      pname = "nfortune";
      version = "1.0.2";

      src = ./.;

      nativeBuildInputs = [ nim just docutils ];

      nimFlags = [
        "-d:release"
        "-p:${nimble.packages."${system}".simple_parseopt}/src"
      ];

      buildPhase = ''
        runHook preBuild
        HOME=$TMPDIR

        nim $nimFlags c src/nfortune
        rst2man doc/nfortune.6.rst > doc/nfortune.6

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        install -Dt $out/bin src/nfortune
        install -Dt $out/share/man/man6 doc/nfortune.6

        runHook postInstall
      '';
    });
  in (utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
      in rec {
        packages.nfortune = nfortuneDeriv { inherit pkgs; };

        defaultPackage = packages.nfortune;

        apps.nfortune = utils.lib.mkApp {
          drv = packages.nfortune;
          exePath = "/bin/nfortune";
        };
        defaultApp = apps.nfortune;
      })
    ) // {
      overlay = (final: prev: {
        nfortune = nfortuneDeriv { pkgs = final; };
      });
    };
}
