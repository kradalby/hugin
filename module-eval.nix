# Eval-time smoke test for the NixOS module: assemble a minimal system with
# and without rootDir set and assert the rendered ExecStart, so a broken
# option or service definition fails `nix flake check` without a VM.
{
  pkgs,
  self,
  nixpkgs,
  system,
}:
let
  inherit (pkgs) lib;

  execStartFor =
    cfg:
    ((import (nixpkgs + "/nixos/lib/eval-config.nix") {
      inherit system;
      modules = [
        self.nixosModules.default
        {
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "/dev/sda1";
            fsType = "ext4";
          };
          system.stateVersion = "24.11";
          services.hugin = cfg;
        }
      ];
    }).config.systemd.services.hugin.serviceConfig.ExecStart
    );

  withoutRoot = execStartFor {
    enable = true;
    contentDir = "/var/lib/munin/gallery/content";
    tailscaleKeyPath = "/run/secrets/hugin-ts-key";
  };
  withRoot = execStartFor {
    enable = true;
    contentDir = "/var/lib/munin/gallery/content";
    rootDir = "/var/lib/munin/gallery/legacy-album";
    tailscaleKeyPath = "/run/secrets/hugin-ts-key";
  };

  check = cond: msg: if cond then true else throw "module-eval: ${msg}";
in
assert check (lib.hasInfix "--content-dir=/var/lib/munin/gallery/content" withoutRoot)
  "ExecStart missing --content-dir: ${withoutRoot}";
assert check (
  !lib.hasInfix "--root-dir=" withoutRoot
) "ExecStart must not set --root-dir when rootDir is unset: ${withoutRoot}";
assert check (lib.hasInfix "--root-dir=/var/lib/munin/gallery/legacy-album" withRoot)
  "ExecStart missing --root-dir when rootDir is set: ${withRoot}";
pkgs.runCommand "hugin-module-eval-ok" { } "touch $out"
