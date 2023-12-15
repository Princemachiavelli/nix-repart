{
  description = "A very basic flake";

  inputs = {
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-anywhere.url = "github:numtide/nixos-anywhere";
    nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, nixos-anywhere, nixos-generators }: let
    pathToDefault = self.nixosConfigurations.default;
    sharedModules = [
          ./common.nix
          ({ config, pkgs, ... }: {
            system.stateVersion = config.system.nixos.version;
            services.sshd.enable = true;
            users.users.root.openssh.authorizedKeys.keys = [
	      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0s7ucRRzdvbUnDCSq6SEfwwnugqFetMKaNOuZfjjmV josh@greyfox"
            ];
            environment.etc."install-default" = {
              source = self.nixosConfigurations.default.config.system.build.diskoScript;
              mode = "0777";
            };
            boot.initrd.systemd.emergencyAccess = true;
            boot.initrd.systemd.initrdBin = with pkgs; [ bash util-linux ];
            users.users.root.hashedPassword = "$6$/tibEVNXmyw69$nS0QMNFnRWtGyKKwaWYo30qtM9uya9VsLNTztFxaNS5pAiU6kcyaEdgyR2B2s6gYL41MYfr1JNmpybPM0Gern1";
          })
    ];
  in {
    # https://github.com/Lassulus/flakes-testing/blob/master/flake.nix
    # https://www.freedesktop.org/software/systemd/man/latest/systemd-repart.html
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.default
        nixos-generators.nixosModules.all-formats
        ./vm.nix
        {
	  _module.args.rootDisk = "vda";
	  environment.systemPackages = [
            nixos-anywhere.packages.x86_64-linux.nixos-anywhere
          ];
          networking.hostName = "vm1";
        }
      ] ++ sharedModules;
    };
    nixosConfigurations.vm2 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.default
        nixos-generators.nixosModules.all-formats
        ./vm.nix
        {
	  _module.args.rootDisk = "vda";
	  environment.systemPackages = [
            nixos-anywhere.packages.x86_64-linux.nixos-anywhere
          ];
          networking.hostName = "vm2";
        }
      ] ++ sharedModules;
    };
    packages."x86_64-linux".installer-iso = let
      installer = nixpkgs.lib.nixosSystem {
        pkgs = self.inputs.nixpkgs.legacyPackages.x86_64-linux;
        system = "x86_64-linux";
        modules = [
          self.inputs.nixos-generators.nixosModules.all-formats
          ({ config, pkgs, ... }: {
            environment.etc."install-nixos" = { 
              source = (pkgs.writeScript "install-system-default" ''
                nixos-install --no-root-password --system ${pathToDefault.config.system.build.toplevel}
              '');
              mode = "0777";
            };
          })
        ] ++ sharedModules;
      };
    in installer.config.formats.install-iso;
  };
}
