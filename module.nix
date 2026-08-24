# NixOS module for hugin. Import via the flake's nixosModules.default.
#
#   services.hugin = {
#     enable = true;
#     contentDir = "/var/lib/munin/gallery/content"; # Munin's targetFolder
#     tailscaleKeyPath = config.age.secrets.hugin-ts-key.path;
#   };
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hugin;
in
{
  imports = [
    # `album` always held Munin's generated content (its targetFolder), never
    # an actual "album" (Munin's own raw-photos sourceFolder) — renamed to
    # say what it is.
    (lib.mkRenamedOptionModule [ "services" "hugin" "album" ] [ "services" "hugin" "contentDir" ])
  ];

  options.services.hugin = {
    enable = lib.mkEnableOption "hugin, an image gallery frontend for munin";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.default;
      defaultText = lib.literalExpression "hugin flake package";
      description = "The hugin package to run.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "hugin";
      description = "Tailnet hostname to serve as.";
    };

    contentDir = lib.mkOption {
      type = lib.types.path;
      description = ''
        Directory containing a Munin-generated gallery (Munin's
        `targetFolder`, holding its `root/` and `keywords/` subfolders).
        Served at /content/.
      '';
    };

    rootDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Directory served at /album/. Defaults to `contentDir` when unset;
        nothing in hugin's own frontend requests /album/ (it is a client-side
        route, not an HTTP path), so this only matters for external
        consumers that rely on that URL directly.
      '';
    };

    tailscaleKeyPath = lib.mkOption {
      type = lib.types.path;
      description = "Path to a file holding the Tailscale auth key.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "hugin";
      description = "User account under which hugin runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "hugin";
      description = "Group account under which hugin runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/hugin";
      description = ''
        Working directory and $HOME for the service. tsnet (Tailscale)
        persists its node identity under $HOME, which systemd sets from this
        directory via the service user's passwd entry, so a stable dataDir
        keeps the tailnet identity across restarts.
      '';
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable verbose logging.";
    };

    controlUrl = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Tailscale control server URL (empty for the default upstream).";
    };

    localhostPort = lib.mkOption {
      type = lib.types.port;
      default = 56664;
      description = "Local (non-Tailscale) listen port.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to an EnvironmentFile sourced by the service, e.g. for
        HUGIN_TOKEN_* variables (exposed to the frontend via /tokens). Keep
        it out of the Nix store (e.g. an agenix/ragenix secret).
      '';
      example = "/var/lib/secrets/huginSecrets";
    };
  };

  config = lib.mkIf cfg.enable {
    # No assertion on contentDir: the option has no default and `types.path`
    # rejects "", so a missing or empty value already fails at eval.
    users.users.${cfg.user} = lib.mkIf (cfg.user == "hugin") {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "hugin service user";
    };
    users.groups.${cfg.group} = lib.mkIf (cfg.group == "hugin") { };

    systemd.services.hugin = {
      description = "hugin, an image gallery frontend for munin";
      wantedBy = [ "multi-user.target" ];
      # nss-lookup.target orders hugin after DNS is resolvable, for the
      # Tailscale control-server connection.
      after = [
        "network-online.target"
        "nss-lookup.target"
      ];
      wants = [
        "network-online.target"
        "nss-lookup.target"
      ];

      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "--hostname=${cfg.hostname}"
            "--tailscale-auth-key-path=${cfg.tailscaleKeyPath}"
            "--content-dir=${cfg.contentDir}"
            "--addr=localhost:${toString cfg.localhostPort}"
          ]
          ++ lib.optional cfg.verbose "--verbose"
          ++ lib.optional (cfg.rootDir != null) "--root-dir=${cfg.rootDir}"
          ++ lib.optional (cfg.controlUrl != "") "--controlurl=${cfg.controlUrl}"
        );

        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "15";
        WorkingDirectory = cfg.dataDir;
        # SIGTERM goes to the main pid rather than the whole cgroup at once.
        KillMode = "mixed";

        # tsnet (via kraweb) is a real Tailscale node: it needs CAP_NET_ADMIN
        # to set the bypass socket mark (SO_MARK). Without it, tailscale
        # falls back to binding sockets to the default-route interface, which
        # breaks connectivity on multi-homed hosts.
        AmbientCapabilities = [ "CAP_NET_ADMIN" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];

        # Hardening. contentDir/rootDir are admin-chosen and may live
        # anywhere (e.g. under /home for a personal gallery), so ProtectHome
        # is deliberately left unset here — it would hide them outright,
        # unlike ReadOnlyPaths which only allow-lists specific paths under
        # ProtectSystem=strict.
        #
        # contentDir alone is not enough: Munin symlinks originals into its
        # sourceFolder, which the operator must grant separately
        # (SupplementaryGroups, or mode bits). ProtectSystem=strict hides
        # nothing, so no setting here substitutes for it.
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
        RestrictNamespaces = true;
        LockPersonality = true;
        SystemCallFilter = [ "@system-service" ];
        SystemCallErrorNumber = "EPERM";

        ReadWritePaths = [ cfg.dataDir ];
        ReadOnlyPaths = lib.unique ([ cfg.contentDir ] ++ lib.optional (cfg.rootDir != null) cfg.rootDir);
      }
      // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
