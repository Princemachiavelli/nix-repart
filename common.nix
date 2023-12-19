{ self, config, modulesPath, pkgs, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];
  nix.settings = {
    stalled-download-timeout = 15;
    experimental-features = [ "nix-command" "flakes" "ca-derivations" "cgroups" "auto-allocate-uids" "repl-flake" ];
  };
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
  boot.initrd.extraFiles = {
    "/etc/ssh/ssh_host_ed25519_key".source = pkgs.writeText "ssh_host_ed25519_key" ''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACD0AtRsHh1cOxNujMD1km+juF0FTiTpkMj13lZ72/y0XgAAAJhQFExRUBRM
UQAAAAtzc2gtZWQyNTUxOQAAACD0AtRsHh1cOxNujMD1km+juF0FTiTpkMj13lZ72/y0Xg
AAAEAneUH/HjmwcnhnqEnjpES5khmZnXK/vzllSMM7/B4YJPQC1GweHVw7E26MwPWSb6O4
XQVOJOmQyPXeVnvb/LReAAAAFGpob2ZmZXJAaW5maW5pdGVqZXN0AQ==
-----END OPENSSH PRIVATE KEY-----
    '';
    "/etc/nix/nix.conf".source = config.environment.etc."nix/nix.conf".source;
  };
  networking.dhcpcd.enable = true;
  system.stateVersion = config.system.nixos.version;
  services.sshd.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0s7ucRRzdvbUnDCSq6SEfwwnugqFetMKaNOuZfjjmV josh@greyfox"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPoveuqLp21hv+hpAX5is1RB/y3aWN21RDFL5qSO3bhI jhoffer@anduril.com"
  ];
  environment.etc."install-default" = {
    source = self.nixosConfigurations.default.config.system.build.diskoScript;
    mode = "0777";
  };
  boot.initrd.systemd.emergencyAccess = true;
  boot.initrd.systemd.initrdBin = with pkgs; [ bash util-linux ];
  users.users.root.hashedPassword = "$6$/tibEVNXmyw69$nS0QMNFnRWtGyKKwaWYo30qtM9uya9VsLNTztFxaNS5pAiU6kcyaEdgyR2B2s6gYL41MYfr1JNmpybPM0Gern1";
}
