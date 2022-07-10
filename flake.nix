{
  description = "hugin - Image gallery frontend for munin";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      headscaleVersion = if (self ? shortRev) then self.shortRev else "dev";
    in
    {
      overlay = final: prev:
        let
          pkgs = nixpkgs.legacyPackages.${prev.system};
        in
        rec { };
    } // flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            overlays = [ self.overlay ];
            inherit system;
          };
          buildDeps = with pkgs; [
            elmPackages.elm
            nodePackages.parcel
            git
            gnumake
          ];
          devDeps = with pkgs;
            buildDeps ++
            (with elmPackages;
            [
              yarn
              elm
              elm-format
              elm-json
              elm-analyse
            ]);


          # Add entry to build a docker image with headscale
          # caveat: only works on Linux
          #
          # Usage:
          # nix build .#headscale-docker
          # docker load < result
          headscale-docker = pkgs.dockerTools.buildLayeredImage {
            name = "headscale";
            tag = headscaleVersion;
            contents = [ pkgs.headscale ];
            config.Entrypoint = [ (pkgs.headscale + "/bin/headscale") ];
          };
        in
        rec {
          # `nix develop`
          devShell = pkgs.mkShell { buildInputs = devDeps; };

          # `nix build`
          packages = with pkgs; {
            inherit headscale;
            inherit headscale-docker;
          };

          defaultPackage = pkgs.headscale;

          # `nix run`
          apps.headscale = flake-utils.lib.mkApp {
            drv = packages.headscale;
          };
          defaultApp = apps.headscale;

          checks = {
            format = pkgs.runCommand "check-format"
              {
                buildInputs = with pkgs; [
                  gnumake
                  nixpkgs-fmt
                  golangci-lint
                  nodePackages.prettier
                  golines
                  clang-tools
                ];
              } ''
              ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt ${./.}
              ${pkgs.golangci-lint}/bin/golangci-lint run --fix --timeout 10m
              ${pkgs.nodePackages.prettier}/bin/prettier --write '**/**.{ts,js,md,yaml,yml,sass,css,scss,html}'
              ${pkgs.golines}/bin/golines --max-len=88 --base-formatter=gofumpt -w ${./.}
              ${pkgs.clang-tools}/bin/clang-format -style="{BasedOnStyle: Google, IndentWidth: 4, AlignConsecutiveDeclarations: true, AlignConsecutiveAssignments: true, ColumnLimit: 0}" -i ${./.}
            '';
          };


        });
}
