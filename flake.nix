{
  description = "XTDB - the temporal database";

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
        let
          gradlePhaseFlags = {
            build = [ "shadowJar" "xtdb-http-server:jar" ];
            check = [ "xtdb-http-server:check" "xtdb-http-server:test" ];
          };
        in
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
              gradleBuildFlags = gradlePhaseFlags.build;
              gradleCheckFlags = gradlePhaseFlags.check;
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
                    name = "build-flake";
                    help = "Build the Nix flake";
                    command = ''
                      sh -x -c 'nix build --print-build-logs --show-trace'
                    '';
                  }
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
                    command =
                      let
                        gradleTasksAll = builtins.concatLists (builtins.attrValues gradlePhaseFlags);
                        cmdLineOptionsTask = builtins.concatStringsSep " " (map (task: "--task \"${task}\"") gradleTasksAll);
                      in
                      ''
                        sh -x -c '
                          nix run ${gradle2nixUrl}#gradle2nix -- \
                            --dump-events \
                            --log debug \
                            ${cmdLineOptionsTask}
                        '
                      '';
                  }
                  {
                    name = "show-gradle-tasks";
                    help = "Show all of the gradle tasks";
                    command = ''
                      sh -x -c './gradlew tasks --all'
                    '';
                  }
                  {
                    name = "show-gradle-task-tree";
                    help = "Show the gradle task tree";
                    command = ''
                      sh -x -c './gradlew taskTree'
                    '';
                  }
                ];
            };
          };
        };
    };
}
