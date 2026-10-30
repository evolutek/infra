{ config, lib, ... }:
{
  sops.secrets."hermes/env" = { };

  services.hermes-agent = {
    # Stays off until OmniRoute serves it a model (evolutek/EvoluBot#9).
    enable = false;
    stateDir = "/srv/hermes";
    environmentFiles = [ config.sops.secrets."hermes/env".path ];
    # These tools would let a prompt-injected agent run code or read its own .env.
    # The setting applies to every session, cron jobs included, which the unit sandbox below does not cover.
    settings.agent.disabled_toolsets = [
      "terminal"
      "code_execution"
      "file"
      "browser"
      "computer_use"
    ];
  };

  systemd.services.hermes-agent = lib.mkIf config.services.hermes-agent.enable {
    serviceConfig = {
      # The upstream module leaves /home visible because its default stateDir may sit there; ours is /srv.
      ProtectHome = lib.mkForce true;
      PrivateDevices = true;
      CapabilityBoundingSet = "";
      AmbientCapabilities = "";
      RestrictSUIDSGID = true;
      LockPersonality = true;
      RestrictRealtime = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" ];
      MemoryMax = "2G";
    };
  };
}
