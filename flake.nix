{
  description = "XTDB - the temporal database";

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

      devShells.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = with nixpkgs.legacyPackages.${system}; [
          jdk21
          gradle
        ] ++ (if (gradle2nix.packages ? ${system} && gradle2nix.packages.${system} ? default)
        then [ gradle2nix.packages.${system}.default ]
        else [ ]);
      };
    });
}
