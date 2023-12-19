{ config, lib, pkgs, modulesPath, ... }:
let
  id = pkgs.writeShellScriptBin "id" ''echo 1'';
  # --make-rprivate does not seem to work or be needed when in initrd.
  mount = pkgs.writeShellScriptBin "mount" ''
    if [ "$1" == "--make-rprivate" ] ; then
            echo "Ignoring"
    else
            ${pkgs.util-linuxMinimal}/bin/mount "$@"
    fi
  '';
  nixosInstall = with config.system.build; nixos-install.overrideAttrs(x: { path =  with pkgs; lib.makeBinPath [ mount jq nixos-enter util-linuxMinimal ]; });
in
{
  imports = [
    ./disko.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.repart.enable = true;
  boot.initrd.systemd.repart.device = "/dev/vda";
  systemd.repart.partitions = {
    "5-boot" = {
      Type = "esp";
      Format = "vfat";
      CopyFiles="/boot:/";
      FactoryReset = "yes";
    };
    "10-root" = {
      Type = "root";
      Format = "btrfs";
      CopyFiles="/boot/nix:/nix";
      Encrypt = "key-file";
      Subvolumes = "/root";
      FactoryReset = "yes";
      MakeDirectories = "/boot";
    };
  };

  boot.initrd.extraFiles."/etc/nix".source = config.environment.etc."nix/nix.conf".source;

  boot.initrd.systemd.mounts = [
    {
      where = "/nix-src";
      what = "/boot/new-image.img";
      type = "loop";
    }
  ];
  boot.initrd.systemd = {
    extraBin = {
      nix = "${pkgs.nix}/bin/nix";
      nixos-install = "${pkgs.nixos-install-tools}/bin/nixos-install";
    };
  };

  boot.initrd.systemd.storePaths = [ pkgs.openssh nixosInstall mount ];
  boot.initrd.supportedFilesystems = [ "vfat" ];

  boot.initrd.systemd.services = {
    systemd-repart = {
      # need systemd v255 to use copy-from images.
      #unitConfig = {
      #  ConditionPathExists = [ "/new-image" ];
      #};
      serviceConfig = let
        initrdCfg = config.boot.initrd.systemd.repart;
      in {
        ExecStart = lib.mkForce [
          ""
          ''
            ${config.boot.initrd.systemd.package}/bin/systemd-repart \
              --definitions=/etc/repart.d \
              --dry-run=yes ${lib.optionalString (initrdCfg.device != null) initrdCfg.device} \
              --empty=allow \
              --discard=yes \
              --factory-reset=yes
          ''
        ];
      };
    };
    ssh-keys = {
      before = [ "sshd.service" ];
      wantedBy = [ "initrd.target" ];
      unitConfig.DefaultDependencies = false;
      path = with pkgs; [ openssh ];
      script = ''
        ssh-keygen -t rsa -N "" -f /etc/ssh/ssh_host_rsa_key
        ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key
        chmod go-rwx /etc/ssh/ssh_host_*_key
      '';
    };
    nixos-repart = {
      enable = true;
      after = [ "cryptsetup.target" ];
      before = [ "initrd-nixos-activation.service" ];
      wantedBy = [ "sysinit.target" ];
      script = ''
          set -uo pipefail
          export PATH="${mount}/bin:${id}/bin:/bin:${pkgs.util-linux}/bin"
          chmod +x /usr/bin/env

          # Figure out what closure to boot
          closure=
          for o in $(< /proc/cmdline); do
              case $o in
                  init=*)
                      IFS== read -r -a initParam <<< "$o"
                      closure="$(dirname "''${initParam[1]}")"
                      ;;
              esac
          done
          export PATH="$PATH:$closure/sw/bin"
          nix --extra-experimental-features "flakes nix-command" copy --no-check-sigs --from /sysroot $closure
          $closure/etc/install-default
          ${nixosInstall}/bin/nixos-install --root /mnt --system $closure --no-root-password --no-channel-copy
          systemctl restart initrd-root-fs.target
      '';
    };
  };
}
