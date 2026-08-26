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
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      flake-checks,
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
            hash = "sha256-CwYXBOxqAt/5VHAzNWABq9zOhNdKLOfGLkYBRBJQszk=";
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
            elmVersion = "0.19.2";
            elmPackages = import ./elm-srcs.nix;
            registryDat = ./registry.dat;
          };

          buildPhase = ''
            runHook preBuild
            mkdir -p $out
            yarn --offline parcel build --log-level verbose --dist-dir $out src/index.html
            # Verbatim, unhashed copies for Views.Assets: Elm has no way to
            # learn parcel's content hashes, so it references these by a
            # stable path instead.
            cp -r src/images $out/images
            runHook postBuild
          '';

          dontInstall = true;
        };

        common = {
          inherit pkgs;
          root = ./.;
          pname = "hugin";
          # Not huginVersion: buildGoModule names the vendored tree
          # "${pname}-${version}-go-modules", so a rev-based version refetches
          # every module on every commit. vendorHash already pins the content.
          # Overriding version afterwards re-derives it, so this stays stable
          # for the binary too.
          version = "0";
          vendorHash = "sha256-OOKI2Ha+R/DwXzJhHwnbCRfr5QOBmm1wzZwN15C3Kto=";
          # go_latest, not a go_1_NN attribute: flake-checks feeds this to
          # `buildGoModule.override { go = goPkg; }`, so this is the
          # buildGoLatestModule equivalent and tracks the newest Go in
          # nixpkgs instead of needing a bump every release.
          goPkg = pkgs.go_latest;

          # Formatting rides on flake-checks too: gofumpt + goimports -local
          # (derived from go.mod) + nixfmt, prettier for the web/doc files, and
          # elm-format for the 36 .elm sources. fmtExts pulls "elm" into the
          # check's source — goFormat's src is fileset-filtered, so without it
          # the .elm files are absent and elm-format would format nothing while
          # the check still went green.
          prettier = true;
          fmtExts = [ "elm" ];
          treefmtExtra = {
            programs.elm-format.enable = true;
            # prettier 3.8 reads .editorconfig by default, and walks past the
            # repo root to find one. hugin has none of its own, so whatever
            # sits in a developer's home directory would silently restyle the
            # frontend — while the sandboxed formatting check, which has no
            # such file, disagrees. Pin it off so both see the same rules.
            settings.formatter.prettier.options = [ "--no-editorconfig" ];
          };
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

        devDeps = with pkgs; [
          # Go toolchain
          go_latest
          gopls
          golangci-lint
          gofumpt

          # Elm/parcel toolchain
          elmPackages.elm
          elmPackages.elm-format
          elmPackages.elm-json
          elmPackages.elm-test-rs
          elm2nix
          sass
          yarn
          nodejs
          python3

          # Tooling
          git
          gnumake
          prek
          (fc.formatter common)
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
        formatter = fc.formatter common;

        checks = {
          # Full Go+Elm build (compiles the Go incl. the dist/* embed).
          build = hugin;

          # elm-test-rs rather than the node elm-test: a single binary, no
          # node_modules, and it runs offline against the ELM_HOME that
          # fetchElmDeps populates (elm-srcs.nix carries the test-dependencies
          # from elm.json, so elm-explorations/test is vendored too).
          elm-test = pkgs.stdenv.mkDerivation {
            pname = "hugin-elm-test";
            version = huginVersion;
            src = pkgs.nix-gitignore.gitignoreSource [
              "Makefile"
              "go.mod"
              "go.sum"
              "*.go"
            ] ./.;

            nativeBuildInputs = with pkgs; [
              elmPackages.elm
              elmPackages.elm-test-rs
              nodejs # elm-test-rs compiles the suite to JS and runs it on node
            ];

            postUnpack = ''
              export HOME="$TMP"
            '';

            postConfigure = pkgs.elmPackages.fetchElmDeps {
              elmVersion = "0.19.2";
              elmPackages = import ./elm-srcs.nix;
              registryDat = ./registry.dat;
            };

            buildPhase = ''
              runHook preBuild
              # --offline: the sandbox has no network, and every package the
              # runner needs is already in ELM_HOME via fetchElmDeps.
              elm-test-rs --offline --compiler ${pkgs.elmPackages.elm}/bin/elm
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              touch $out
              runHook postInstall
            '';
          };

          # go test / golangci-lint against the Go source with the Elm build
          # output (huginElm) injected into dist/, mirroring hugin's own
          # postPatch so the //go:embed dist/* target exists.
          gotest = (fc.goTest common).overrideAttrs withDist;
          golangci-lint = (fc.goLint common).overrideAttrs withDist;

          # goimports shells out to `go` to resolve imports, which drags two
          # sandbox problems in that have nothing to do with formatting:
          #
          #   * `go` wants a writable module cache under $HOME, and the sandbox
          #     points HOME at /homeless-shelter, which it cannot create.
          #   * go.mod asks for 1.27, so any older `go` on PATH tries to fetch
          #     that toolchain and the sandbox has no network. goimports uses
          #     the `go` it finds on PATH, not the one it was built against, so
          #     rebuilding gotools does not help — putting go_latest first and
          #     refusing to switch toolchains does.
          #
          # Either one surfaces as `goimports: exit status 2`, which treefmt
          # then reports as a formatting failure.
          formatting = (fc.goFormat common).overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.go_latest ];
            GOTOOLCHAIN = "local";
            buildCommand = ''
              export HOME="$TMPDIR"
            ''
            + old.buildCommand;
          });

          # prek still runs the full hook set on `git commit`, but its hooks
          # come from remote repos and so cannot run in a sandbox. shellcheck
          # is the one hook doing analysis rather than formatting that no
          # other check covers, so it moves into the flake where garnix runs
          # it. Everything else prek does is either a formatter treefmt
          # already gates, or a local-only guard.
          shellcheck = pkgs.runCommand "hugin-shellcheck" { buildInputs = [ pkgs.shellcheck ]; } ''
            cd ${pkgs.nix-gitignore.gitignoreSource [ ] ./.}
            found=0
            while IFS= read -r script; do
              found=1
              echo "shellcheck $script"
              shellcheck "$script"
            done < <(find . -name '*.sh' -type f)

            if [ "$found" -eq 0 ]; then
              echo "no shell scripts found; the check would be vacuous" >&2
              exit 1
            fi

            touch $out
          '';
        }
        # NixOS module evaluation needs a Linux system.
        // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
