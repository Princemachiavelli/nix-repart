{ config, lib, ... }:
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

  boot.initrd.systemd.mounts = [
    {
      where = "/nix-src";
      what = "/boot/new-image.img";
      type = "loop";
    }
  ];

  boot.initrd.systemd.services.systemd-repart = {
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
}
