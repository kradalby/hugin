{
  description = "hugin - Image gallery frontend for munin";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    }:
    let
      huginVersion =
        if (self ? shortRev)
        then self.shortRev
        else "dev";

      huginOverlay = _final: prev: rec {
        huginElm = prev.stdenv.mkDerivation {
          name = "huginElm";
          src = prev.nix-gitignore.gitignoreSource [ "Makefile" "go.mod" "go.sum" "*.go" ] ./.;

          # yarn2nix was removed from nixpkgs; use the standard yarn v1 hooks.
          # yarnConfigHook populates ./node_modules from yarnOfflineCache.
          nativeBuildInputs = with prev; [
            yarnConfigHook
            nodejs
            elmPackages.elm
            sass
            python313
          ];

          yarnOfflineCache = prev.fetchYarnDeps {
            yarnLock = ./yarn.lock;
            sha256 = "0jjhnj5fxnz981zwsv9qcczji6bfi2iv6mlvjkmbzf5gwhg5a5ri";
          };

          postUnpack = ''
            export HOME="$TMP"
          '';

          # Fetch Elm 0.19.1 packages into ELM_HOME before the parcel build.
          preBuild = prev.elmPackages.fetchElmDeps {
            elmVersion = "0.19.1";
            elmPackages = import ./elm-srcs.nix;
            registryDat = ./registry.dat;
          };

          buildPhase = ''
            runHook preBuild
            rm -rf elm-stuff
            mkdir -p $out
            node_modules/.bin/parcel build --log-level verbose --dist-dir $out src/index.html
            runHook postBuild
          '';

          dontInstall = true;
        };

        hugin = prev.callPackage
          ({ buildGoModule, lib }:
            buildGoModule {
              pname = "hugin";
              version = huginVersion;
              src = prev.nix-gitignore.gitignoreSource [ ] ./.;

              buildInputs = [ huginElm ];

              patchPhase = ''
                cp -r ${huginElm} dist
              '';

              vendorHash = "sha256-GhosEPXxhcBng9OrkX7VvfhnGZr6/0UkkM66cILfZRY=";

              meta = {
                description = "Image gallery frontend for munin";
                homepage = "https://github.com/kradalby/hugin";
                license = lib.licenses.agpl3Only;
                mainProgram = "hugin";
              };
            })
          { };
      };
    in
    {
      overlays.default = huginOverlay;
    }
    // flake-utils.lib.eachDefaultSystem
      (system:
      let
        pkgs = import nixpkgs {
          overlays = [ self.overlays.default ];
          inherit system;
        };
        buildDeps = with pkgs; [
          nodejs
          yarn
          elmPackages.elm
          sass
          git
          gnumake
          go
        ];
        devDeps = with pkgs;
          buildDeps
          ++ [
            # Tooling
            elm2nix
            golangci-lint
            nixpkgs-fmt
            prek
            prettier
            yarn

            # Elm toolchain
            elmPackages.elm
            elmPackages.elm-format
            elmPackages.elm-json
          ];
      in
      {
        # `nix develop`
        devShells.default = pkgs.mkShell { buildInputs = devDeps; };

        # `nix build`
        packages = {
          inherit (pkgs) hugin;
          default = pkgs.hugin;
        };

        # `nix run`
        apps = rec {
          hugin = (flake-utils.lib.mkApp {
            drv = pkgs.hugin;
          }) // {
            meta = pkgs.hugin.meta or { };
          };
          default = hugin;
        };

        # `nix fmt`
        formatter = pkgs.writeShellApplication {
          name = "hugin-fmt";
          runtimeInputs = with pkgs; [ nixpkgs-fmt prettier ];
          text = ''
            nixpkgs-fmt "''${@:-.}"
            prettier --write '**/*.{ts,js,md,yaml,yml,sass,css,scss,html}'
          '';
        };

        checks = {
          # Full Go+Elm build (compiles the Go incl. the dist/* embed).
          build = self.packages.${system}.hugin;

          # gotest / golangci-lint run against the Go source with the Elm
          # build output (huginElm) injected into dist/, mirroring the
          # package's patchPhase so the //go:embed dist/* target exists.
          gotest = pkgs.hugin.overrideAttrs (_old: {
            pname = "hugin-gotest";
            doCheck = true;
          });

          golangci-lint = pkgs.hugin.overrideAttrs (old: {
            pname = "hugin-golangci-lint";
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.golangci-lint ];
            postBuild = (old.postBuild or "") + ''
              HOME=$TMPDIR golangci-lint run ./...
            '';
          });

          formatting =
            pkgs.runCommand "check-formatting"
              {
                buildInputs = with pkgs; [
                  nixpkgs-fmt
                  prettier
                ];
              } ''
              cp -r ${./.} source
              chmod -R u+w source
              cd source
              nixpkgs-fmt --check .
              prettier --check '**/*.{ts,js,md,yaml,yml,sass,css,scss,html}'
              touch $out
            '';
        };
      })
    // {
      nixosModules.default =
        { pkgs
        , lib
        , config
        , ...
        }:
        let
          cfg = config.services.hugin;
        in
        {
          options = with lib; {
            services.hugin = {
              enable = mkEnableOption "Enable hugin";

              package = mkOption {
                type = types.package;
                description = ''
                  hugin package to use
                '';
                default = pkgs.hugin;
              };

              dataDir = mkOption {
                type = types.path;
                default = "/var/lib/hugin";
                description = "Path to data dir";
              };

              user = mkOption {
                type = types.str;
                default = "hugin";
                description = "User account under which hugin runs.";
              };

              group = mkOption {
                type = types.str;
                default = "hugin";
                description = "Group account under which hugin runs.";
              };

              tailscaleKeyPath = mkOption {
                type = types.path;
              };

              album = mkOption {
                type = types.path;
              };

              verbose = mkOption {
                type = types.bool;
                default = false;
              };

              controlUrl = mkOption {
                type = types.str;
                default = "";
              };

              localhostPort = mkOption {
                type = types.port;
                default = 56664;
              };

              environmentFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                example = "/var/lib/secrets/huginSecrets";
              };
            };
          };
          config = lib.mkIf cfg.enable {
            systemd.services.hugin = {
              enable = true;
              script =
                let
                  args =
                    [
                      "--tailscale-auth-key-path ${cfg.tailscaleKeyPath}"
                      "--album ${cfg.album}"
                      "--addr localhost:${toString cfg.localhostPort}"
                    ]
                    ++ lib.optionals cfg.verbose [ "--verbose" ];
                in
                ''
                  ${cfg.package}/bin/hugin ${builtins.concatStringsSep " " args}
                '';
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              serviceConfig = {
                User = cfg.user;
                Group = cfg.group;
                Restart = "always";
                RestartSec = "15";
                WorkingDirectory = "${cfg.dataDir}";
                EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
              };
              path = [ cfg.package ];
              environment = { };
            };
          };
        };
    };
}
