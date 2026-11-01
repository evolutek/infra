{ config, pkgs, evolubot, ... }:
let
  python = pkgs.python3.withPackages (p: [ p.pyyaml ]);
in
{
  # OMNIROUTE_BENCH_KEY.
  sops.secrets."bench/env".owner = "bench";

  users.users.bench = {
    isSystemUser = true;
    group = "bench";
    home = "/srv/bench";
  };
  users.groups.bench = { };

  systemd.tmpfiles.rules = [ "d /srv/bench 0700 bench bench -" ];

  systemd.services.bench = {
    description = "Banc d'essai des modèles de l'agent";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "podman-omniroute.service" ];
    # Starting empty would run everything again and spend the quotas twice: wait for the imported journal.
    unitConfig.ConditionPathExists = "/srv/bench/resultats/journal.jsonl";
    path = [ python pkgs.nodejs_22 pkgs.bubblewrap pkgs.util-linux pkgs.stdenv.cc pkgs.bash ];
    environment = {
      OMNIROUTE_URL = "http://127.0.0.1:20128/v1";
      BENCH_RESULTATS = "/srv/bench/resultats";
      HOME = "/srv/bench";
      npm_config_cache = "/srv/bench/npm";
    };
    serviceConfig = {
      User = "bench";
      Group = "bench";
      ExecStart = "${python}/bin/python3 ${evolubot}/bench/lancer.py run --max-processus 6";
      EnvironmentFile = config.sops.secrets."bench/env".path;
      Restart = "on-failure";
      RestartSec = 120;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/srv/bench" ];
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      RestrictSUIDSGID = true;
      LockPersonality = true;
      ProtectClock = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      SystemCallArchitectures = "native";
      # bwrap, which runs the code written by the models, mounts a fresh /proc in its own namespaces. The kernel
      # refuses it if /proc is partly masked, hence no ProtectKernelLogs, ProtectKernelTunables or ProtectHostname;
      # it also needs @mount and no RestrictNamespaces. Without them every code case would score 0 silently.
      SystemCallFilter = [ "@system-service" "@mount" ];
      MemoryMax = "3G";
      TasksMax = 512;
    };
  };
}
