{ config, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];
  systemd.watchdog = {
    runtimeTime = "30s";
    rebootTime = "10m";
    kexecTime = "5m";
  };

  systemd.extraConfig = ''
    DefaultTimeoutStartSec=15s
    DefaultTimeoutStopSec=15s
    DefaultDeviceTimeoutSec=15s
  '';

  boot.initrd.systemd.extraConfig = config.systemd.extraConfig;
  # No watchdog in initrd? :/
  #boot.initrd.systemd.watchdog = config.systemd.watchdog;
  services.qemuGuest.enable = true;

  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      ignoreEmptyHostKeys = true;
    };
  };
  networking.dhcpcd.enable = true;
}
