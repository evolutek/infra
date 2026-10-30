# by-path names follow the motherboard port, not the drive: unlike by-id they carry no serial
# number (this repo is public) and, unlike sdX, they do not swap between boots.
let
  luks = name: content: {
    type = "luks";
    inherit name;
    # Only used once by disko at install time; TPM and a recovery key replace it afterwards.
    passwordFile = "/tmp/luks-install.key";
    settings = {
      allowDiscards = true;
      crypttabExtraOpts = [ "tpm2-device=auto" ];
    };
    inherit content;
  };
in
{
  disko.devices.disk = {
    system = {
      type = "disk";
      device = "/dev/disk/by-path/pci-0000:01:00.0-nvme-1";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          system = {
            size = "100%";
            content = luks "crypt-system" {
              type = "btrfs";
              extraArgs = [ "-L" "system" ];
              subvolumes =
                let opts = [ "compress=zstd" "noatime" ];
                in {
                  "@root" = { mountpoint = "/"; mountOptions = opts; };
                  "@nix" = { mountpoint = "/nix"; mountOptions = opts; };
                  "@var" = { mountpoint = "/var"; mountOptions = opts; };
                  "@home" = { mountpoint = "/home"; mountOptions = opts; };
                };
            };
          };
        };
      };
    };

    data = {
      type = "disk";
      device = "/dev/disk/by-path/pci-0000:00:17.0-ata-2";
      content = {
        type = "gpt";
        partitions.data = {
          size = "100%";
          content = luks "crypt-data" {
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" "data" ];
            mountpoint = "/srv";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };

    archive = {
      type = "disk";
      device = "/dev/disk/by-path/pci-0000:00:17.0-ata-3";
      content = {
        type = "gpt";
        partitions.archive = {
          size = "100%";
          content = luks "crypt-archive" {
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" "archive" ];
            mountpoint = "/archive";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };
}
