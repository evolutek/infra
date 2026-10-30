{ ... }:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../modules/services/hermes.nix
    ../../modules/services/tailscale.nix
  ];

  # Decrypted at boot with the age key derived from the SSH host key.
  sops.defaultSopsFile = ../../secrets/evo-serv1.yaml;

  networking.hostName = "evo-serv1";

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10;
  };
  boot.loader.efi.canTouchEfiVariables = true;
  # The systemd initrd is what reads crypttab's tpm2-device option to unlock LUKS without a prompt.
  boot.initrd.systemd.enable = true;
  security.tpm2.enable = true;

  networking.useNetworkd = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "yes";
  };

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";

  zramSwap.enable = true;

  services.btrfs.autoScrub.enable = true;
  services.fstrim.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.mutableUsers = false;
  users.users.grand-conseil = {
    isNormalUser = true;
    description = "Administration du club";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN0mkNXaoou77aufonQczyTjrB1vnetxvwVnlirJzdxV"
    ];
  };
  # Accounts have no password (mutableUsers = false), so sudo relies on the SSH key alone.
  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  # Deploying runs from a clone of this repository, and a flake only reads git-tracked files.
  programs.git.enable = true;

  system.stateVersion = "26.05";
}
