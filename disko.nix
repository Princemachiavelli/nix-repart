{ config, lib, rootDisk ? "vda", ... }:
{
  disko.devices = {
    disk = {
      ${rootDisk} = {
        type = "disk";
        device = "/dev/${rootDisk}";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            luks1 = {
              size = "100%";
              content = {
                type = "luks";
                name = "luks1";
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "btrfs";
                  subvolumes = {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [ "noatime" "compress=zstd" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
