{ config, ... }:
{
  sops.secrets."omniroute/env".owner = "omniroute";

  # Rootless podman needs a real home for its image store and subordinate ids for the user namespace.
  users.users.omniroute = {
    isSystemUser = true;
    group = "omniroute";
    uid = 970;
    home = "/var/lib/omniroute";
    createHome = true;
    linger = true;
    autoSubUidGidRange = true;
  };
  users.groups.omniroute.gid = 970;

  systemd.tmpfiles.rules = [ "d /srv/omniroute 0700 omniroute omniroute -" ];

  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.omniroute = {
    # Pinned by digest: a tag can be moved upstream, the digest cannot. Update both together.
    image = "docker.io/diegosouzapw/omniroute:3.8.52@sha256:b08a12e876baa8a5ccadd1ebbe346fe7267dba3b1c9f4fd6bb02070fae41ab6c";
    podman.user = "omniroute";
    # Loopback only: Hermes runs on this host, admins reach the dashboard through an SSH tunnel.
    ports = [ "127.0.0.1:20128:20128" ];
    volumes = [ "/srv/omniroute:/app/data" ];
    environment = {
      NODE_ENV = "production";
      DATA_DIR = "/app/data";
      PORT = "20128";
      REQUIRE_API_KEY = "true";
      # Upstream defaults, pinned so a change of default cannot route prompts through third parties.
      CLOUD_URL = "";
      FREE_PROXY_AUTO_SYNC_ENABLED = "false";
      # Public leaderboard fetch the agent does not use.
      ARENA_ELO_SYNC_ENABLED = "false";
    };
    # JWT_SECRET, API_KEY_SECRET, STORAGE_ENCRYPTION_KEY, INITIAL_PASSWORD.
    environmentFiles = [ config.sops.secrets."omniroute/env".path ];
    extraOptions = [
      # The image runs as node (1000); map it to the omniroute user so it owns /srv/omniroute.
      "--userns=keep-id:uid=1000,gid=1000"
      "--cap-drop=ALL"
      "--security-opt=no-new-privileges"
      "--read-only"
      "--tmpfs=/tmp"
      # Next.js writes its prerender cache under the app; keep the root read-only and give it a tmpfs.
      "--tmpfs=/app/.build/next/cache"
      "--memory=1g"
      "--pids-limit=256"
    ];
  };
}
