{
  description = "hugin - Image gallery frontend for munin";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    huginVersion =
      if (self ? shortRev)
      then self.shortRev
      else "dev";
  in
    {
      overlay = _: prev: let
        pkgs = nixpkgs.legacyPackages.${prev.system};
      in rec {
        huginDeps = pkgs.yarn2nix-moretea.mkYarnPackage {
          name = "huginYarnDeps";
          src = pkgs.nix-gitignore.gitignoreSource ["Makefile" "go.mod" "go.sum" "*.go"] ./.;
          publishBinsFor = [
            "parcel"
          ];
        };

        huginElm = pkgs.stdenv.mkDerivation {
          name = "huginElm";
          src = pkgs.nix-gitignore.gitignoreSource ["Makefile" "go.mod" "go.sum" "*.go"] ./.;

          buildInputs = with pkgs; [
            huginDeps

            elmPackages.elm
            yarn
            nodejs
            nodePackages.sass

            python311
          ];

          postUnpack = ''
            export HOME="$TMP"
          '';

          patchPhase = ''
            rm -rf elm-stuff
            ln -fs ${huginDeps}/libexec/hugin/node_modules .
          '';

          configurePhase = pkgs.elmPackages.fetchElmDeps {
            elmVersion = "0.19.1";
            elmPackages = import ./elm-srcs.nix;
            registryDat = ./registry.dat;
          };

          dontBuild = true;

          installPhase = ''
            mkdir -p $out
            parcel build --log-level verbose --dist-dir $out src/index.html
          '';
        };

        hugin = pkgs.buildGo122Module {
          pname = "hugin";
          version = huginVersion;
          src = pkgs.nix-gitignore.gitignoreSource [] ./.;

          buildInputs = [huginElm];

          patchPhase = ''
            cp -r ${huginElm} dist
          '';

          vendorHash = "sha256-xSs/dqjrOTwZu2nL8K5F1xZcOvc1VFTSF3pzzSb68Gk=";
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {
        overlays = [self.overlay];
        inherit system;
      };
      buildDeps = with pkgs; [
        huginDeps
        elmPackages.elm
        nodePackages.sass
        git
        gnumake
        go_1_22
      ];
      devDeps = with pkgs;
        buildDeps
        ++ (with elmPackages; [
          golangci-lint
          yarn
          elm
          elm-format
          elm-json
          elm-analyse
          elm2nix
        ]);
    in rec {
      # `nix develop`
      devShell = pkgs.mkShell {buildInputs = devDeps;};

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

      overlays.default = self.overlay;

      checks = {
        format =
          pkgs.runCommand "check-format"
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
    })
    // {
      nixosModules.default = {
        pkgs,
        lib,
        config,
        ...
      }: let
        cfg = config.services.hugin;
      in {
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
              type = types.string;
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
            script = let
              args =
                [
                  "--tailscale-auth-key-path ${cfg.tailscaleKeyPath}"
                  "--album ${cfg.album}"
                  "--addr localhost:${toString cfg.localhostPort}"
                ]
                ++ lib.optionals cfg.verbose ["--verbose"];
            in ''
              ${cfg.package}/bin/hugin ${builtins.concatStringsSep " " args}
            '';
            wantedBy = ["multi-user.target"];
            after = ["network-online.target"];
            serviceConfig = {
              User = cfg.user;
              Group = cfg.group;
              Restart = "always";
              RestartSec = "15";
              WorkingDirectory = "${cfg.dataDir}";
              EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
            };
            path = [cfg.package];
            environment = {};
          };
        };
      };
    };
}
