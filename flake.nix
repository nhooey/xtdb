{
  description = "XTDB - the temporal database";

  # To build, run the following commands:
  # -------------------------------------
  # nix develop
  # gradle-lock     # inside the `nix develop` shell
  # exit            # to leave the `nix develop` shell
  #
  # nix build --print-build-logs --show-trace

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gradle2nix = {
      url = "github:nhooey/gradle2nix/v2_bugfix-remove-param-console-plain";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , flake-parts
    , devshell
    , gradle2nix
    , ...
    }@inputs:

    inputs.flake-parts.lib.mkFlake { inherit inputs; } rec {

      systems = inputs.flake-utils.lib.defaultSystems;
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.devshell.flakeModule
      ];

      perSystem =
        { pkgs
        , system
        , config
        , ...
        }:
        {
          _module.args.pkgs = import self.inputs.nixpkgs {
            inherit system;
          };

          packages = {
            default = self.inputs.gradle2nix.builders.${system}.buildGradlePackage {
              pname = "xtdb";
              version = "2.x-SNAPSHOT";
              src = self;
              sourceRoot = "source";
              lockFile = ./gradle.lock;
              gradleFlags = [ "-Pversion=2.x-SNAPSHOT" ];
              gradleBuildFlags = [ "xtdb-http-server:jar" ];
              gradleCheckFlags = [ "xtdb-http-server:check" "xtdb-http-server:test" ];
              # gradleInstallFlags = [  ];
              java = nixpkgs.legacyPackages.${system}.jdk21;

              installPhase = ''
                mkdir -pv "$out"
              '';

              postUnpack = "sh -x";
              postPatch = "sh -x";

              nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [
                gradle
                (protobuf.overrideAttrs (oldAttrs: rec {
                  version = "4.31.1";
                  src = fetchFromGitHub {
                    owner = "protocolbuffers";
                    repo = "protobuf";
                    rev = "v${version}";
                    sha256 = "sha256-E8q8XupOXoCFpXyGNHArfBmVm6ebfDgaJlJyvMqpveU=";
                  };
                  doInstallCheck = false; # Version check fails because it outputs only: `31.1`
                }))
              ];

              doCheck = false;
              meta = {
                description = "XTDB - the temporal database";
                homepage = "https://xtdb.com";
                license = nixpkgs.lib.licenses.mpl20;
                mainProgram = "xtdb";
              };
            };
          };

          devshells = {
            default = {
              packages = [
                pkgs.jdk21
                pkgs.gradle
              ];

              commands =
                let
                  gradle2nixUrl = "github:nhooey/gradle2nix/v2_bugfix-remove-param-console-plain";
                in
                [
                  {
                    name = "lock-flake";
                    help = "Update Nix flakes in file: `flake.lock`";
                    command = ''
                      sh -x -c 'nix flake lock --recreate-lock-file'
                    '';
                  }
                  {
                    name = "lock-gradle";
                    help = "Update gradle dependencies in file: `gradle.lock`";
                    command = ''
                      sh -x -c '
                        nix run ${gradle2nixUrl}#gradle2nix -- \
                          --dump-events \
                          --log debug \
                          --task "xtdb-http-server:jar" \
                          --task "xtdb-http-server:check" \
                          --task "xtdb-http-server:test"
                      '
                    '';
                  }
                  {
                    name = "build";
                    help = "Build the Nix flake";
                    command = ''
                      sh -x -c 'nix build --print-build-logs --show-trace'
                    '';
                  }
                ];
            };
          };
        };
    };
}
