{
  description = "hugin - Image gallery frontend for munin";

  inputs = {
    # Spelled out rather than the `nixpkgs/...` indirect ref, which resolves
    # through the local flake registry and so re-locks differently per machine.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-checks.url = "github:kradalby/flake-checks";
    flake-checks.inputs.nixpkgs.follows = "nixpkgs";
    flake-checks.inputs.flake-utils.follows = "flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      flake-checks,
      treefmt-nix,
    }:
    let
      huginVersion = if (self ? shortRev) then self.shortRev else "dev";
    in
    {
      # A thin alias onto the per-system package, so downstream flakes can
      # `overlays.default` their way to `pkgs.hugin` without re-evaluating the
      # build recipe against a partial (pre-overlay) package set.
      overlays.default = _final: prev: {
        hugin = self.packages.${prev.system}.default;
      };

      nixosModules.default = import ./module.nix self;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        fc = flake-checks.lib;

        # The Elm/parcel frontend, built entirely in nix (no ad-hoc `npm run`).
        # yarn deps are vendored via fetchYarnDeps/yarnConfigHook (the standard
        # yarn v1 hooks; yarn2nix itself was removed from nixpkgs). Elm deps
        # via fetchElmDeps + the pinned elm-srcs.nix/registry.dat (elm2nix).
        huginElm = pkgs.stdenv.mkDerivation {
          pname = "huginElm";
          version = huginVersion;
          src = pkgs.nix-gitignore.gitignoreSource [ "Makefile" "go.mod" "go.sum" "*.go" ] ./.;

          yarnOfflineCache = pkgs.fetchYarnDeps {
            yarnLock = ./yarn.lock;
            hash = "sha256-MRdVHuSvuL/qlJtWs6OIbpkoP2M4bc1/QOnb7oq0UEo=";
          };

          nativeBuildInputs = with pkgs; [
            yarnConfigHook
            nodejs
            elmPackages.elm
            sass
            python3
          ];

          postUnpack = ''
            export HOME="$TMP"
          '';

          # yarnConfigHook already installed node_modules by this point (it
          # runs as part of the default configurePhase's postConfigureHooks);
          # this fetches the pinned Elm packages into ELM_HOME so `elm make`
          # never touches the network.
          postConfigure = pkgs.elmPackages.fetchElmDeps {
            elmVersion = "0.19.1";
            elmPackages = import ./elm-srcs.nix;
            registryDat = ./registry.dat;
          };

          buildPhase = ''
            runHook preBuild
            mkdir -p $out
            yarn --offline parcel build --log-level verbose --dist-dir $out src/index.html
            runHook postBuild
          '';

          dontInstall = true;
        };

        common = {
          inherit pkgs;
          root = ./.;
          pname = "hugin";
          version = huginVersion;
          vendorHash = "sha256-gjZAe5N7Q1mHYix6AGFLkYBcbxYhqG4F3N4CSHrA0bY=";
          goPkg = pkgs.go_1_26;
        };

        # flake-checks only knows about Go sources, so the Elm/parcel build
        # (huginElm) is layered on top here: copy its output into dist/ so
        # main.go's `//go:embed dist/*` has something to embed, mirroring
        # what the patchPhase used to do directly against buildGoModule.
        withDist = old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ huginElm ];
          postPatch = (old.postPatch or "") + "cp -r ${huginElm} dist";
        };

        meta = {
          description = "Image gallery frontend for munin";
          homepage = "https://github.com/kradalby/hugin";
          license = pkgs.lib.licenses.agpl3Only;
          mainProgram = "hugin";
        };

        hugin = (fc.goBuild common).overrideAttrs (old: (withDist old) // { inherit meta; });

        # gofumpt + goimports -local + nixfmt (RFC 166, the fleet-wide nix
        # formatter) + prettier (web/doc) + elm-format. flake-checks'
        # `formatter` helper is Go-only and doesn't know about Elm, so this
        # repo wires its own treefmt-nix instead of routing through it.
        treefmtEval = treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "go.mod";
          programs = {
            gofumpt.enable = true;
            goimports.enable = true;
            nixfmt.enable = true;
            prettier.enable = true;
            elm-format.enable = true;
          };
          settings.formatter.goimports.options = [
            "-w"
            "-local"
            "github.com/kradalby/hugin"
          ];
        };

        devDeps = with pkgs; [
          # Go toolchain
          go_1_26
          gopls
          golangci-lint
          gofumpt

          # Elm/parcel toolchain
          elmPackages.elm
          elmPackages.elm-format
          elmPackages.elm-json
          elm2nix
          sass
          yarn
          nodejs
          python3

          # Tooling
          git
          gnumake
          prek
          treefmtEval.config.build.wrapper
        ];
      in
      {
        # `nix develop`
        devShells.default = pkgs.mkShell { buildInputs = devDeps; };

        # `nix build`
        packages = {
          inherit hugin huginElm;
          default = hugin;
        };

        # `nix run`. The meta passthrough is what makes `nix run` report a
        # description/mainProgram instead of the bare app path.
        apps =
          let
            app = flake-utils.lib.mkApp { drv = hugin; } // {
              inherit (hugin) meta;
            };
          in
          {
            hugin = app;
            default = app;
          };

        # `nix fmt`
        formatter = treefmtEval.config.build.wrapper;

        checks = {
          # Full Go+Elm build (compiles the Go incl. the dist/* embed).
          build = hugin;

          # go test / golangci-lint against the Go source with the Elm build
          # output (huginElm) injected into dist/, mirroring hugin's own
          # postPatch so the //go:embed dist/* target exists.
          gotest = (fc.goTest common).overrideAttrs withDist;
          golangci-lint = (fc.goLint common).overrideAttrs withDist;

          formatting = treefmtEval.config.build.check (pkgs.nix-gitignore.gitignoreSource [ ] ./.);
        }
        # NixOS module evaluation needs a Linux system.
        // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          module-eval = import ./module-eval.nix {
            inherit
              pkgs
              self
              nixpkgs
              system
              ;
          };
        };
      }
    );
}
