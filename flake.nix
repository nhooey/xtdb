{
  description = "XTDB - the temporal database";

  # To build, run the following commands:
  # -------------------------------------
  # nix develop
  # nix run github:nhooey/gradle2nix/v2_bugfix-remove-param-console-plain#gradle2nix -- --log debug --task shadowJar --dump-events
  # exit  # to leave the `nix develop` shell
  # nix build --print-build-logs --show-trace

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gradle2nix = {
      url = "github:nhooey/gradle2nix/v2_bugfix-remove-param-console-plain";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, gradle2nix }:
    flake-utils.lib.eachDefaultSystem (system: {
      packages = {
        default = gradle2nix.builders.${system}.buildGradlePackage {
          pname = "xtdb";
          version = "2.x-SNAPSHOT";
          src = self;
          sourceRoot = "source";
          lockFile = ./gradle.lock;
          gradleFlags = [ "-Pversion=2.x-SNAPSHOT" ];
          gradleBuildFlags = [ "build" "shadowJar" ];
          java = nixpkgs.legacyPackages.${system}.jdk21;

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

      devShells.default =
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.mkShell {
          buildInputs = [
            pkgs.jdk21
            pkgs.gradle
          ] ++ (if (gradle2nix.packages ? ${system} && gradle2nix.packages.${system} ? default)
          then [ gradle2nix.packages.${system}.default ]
          else [ ]);
        };
    });
}
