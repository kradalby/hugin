{
  description = "hugin - Image gallery frontend for munin";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      huginVersion = if (self ? shortRev) then self.shortRev else "dev";
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
        in
        rec {
          # `nix develop`
          devShell = pkgs.mkShell { buildInputs = devDeps; };

          # `nix build`
          packages = with pkgs; {
            inherit hugin;
          };

          defaultPackage = pkgs.hugin;

          # `nix run`
          apps.hugin = flake-utils.lib.mkApp {
            drv = packages.hugin;
          };
          defaultApp = apps.hugin;

          checks = {
            format = pkgs.runCommand "check-format"
              {
                buildInputs = with pkgs; [
                  gnumake
                  nixpkgs-fmt
                  nodePackages.prettier
                ];
              } ''
              ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt ${./.}
              ${pkgs.nodePackages.prettier}/bin/prettier --write '**/**.{ts,js,md,yaml,yml,sass,css,scss,html}'
            '';
          };
        });
}
