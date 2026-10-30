# Comprendre NixOS avec ce dépôt

Pour un membre du club qui n'a jamais touché à NixOS et doit lire, modifier ou réinstaller un serveur. On part des idées, puis on lit les fichiers du dépôt un par un. Le code lui-même reste peu commenté : c'est cette page qui l'explique.

## Les quatre idées à retenir

**1. On décrit la machine, on ne la modifie pas.** Sur Debian, on installe un paquet avec `apt install`, on édite `/etc/ssh/sshd_config`, et l'état de la machine est la somme de tout ce qu'on a fait à la main. Sur NixOS, on écrit dans un fichier « SSH activé, mots de passe interdits », puis on demande à NixOS de construire le système qui correspond. Ce qu'on ne décrit pas n'existe pas.

**2. Tout est construit dans le *store*.** Chaque paquet, chaque fichier de configuration généré va dans `/nix/store/<empreinte>-<nom>`, où l'empreinte dépend de tout ce qui a servi à le construire. Deux versions d'un même logiciel cohabitent sans conflit. Le reste du système (`/etc`, `/run/current-system`) n'est qu'un ensemble de liens vers le store.

**3. Chaque construction est une *génération*.** `nixos-rebuild switch` construit un nouveau système complet, puis bascule dessus. L'ancien reste dans le store et au menu de démarrage : si la nouvelle version casse quelque chose, on redémarre sur la précédente. C'est ce qui permet les mises à jour sans personne au local ([ADR-0001](decisions/0001-nixos.md)).

**4. Le *flake* fige les versions.** Le fichier `flake.lock` note le commit exact de nixpkgs (le dépôt qui contient tous les paquets et modules). La même configuration, reconstruite dans deux ans sur une autre machine, donne le même système.

## Le langage Nix en cinq minutes

Nix est un langage de description, pas de script : un fichier `.nix` est une seule valeur, le plus souvent un ensemble d'attributs.

| Syntaxe | Sens |
|---|---|
| `{ a = 1; b = "texte"; }` | ensemble d'attributs (comme un objet JSON) |
| `a.b.c = true;` | raccourci pour `a = { b = { c = true; }; };` |
| `[ "x" "y" ]` | liste (sans virgules) |
| `x: x + 1` | fonction à un argument |
| `{ pkgs, ... }: { … }` | fonction qui prend un ensemble et en garde `pkgs` ; `...` accepte le reste |
| `let x = 1; in x + 1` | variables locales |
| `inherit name;` | raccourci pour `name = name;` |
| `./chemin.nix` | chemin relatif au fichier, copié dans le store |

Pour essayer : `nix repl`, puis taper des expressions.

## Les modules et les options

Une configuration NixOS est faite de **modules**. Un module est un fichier qui donne des valeurs à des **options** : `services.openssh.enable`, `networking.hostName`, etc. NixOS fusionne tous les modules importés, vérifie les types, puis construit le système.

- Toutes les options existantes, avec leur description : [search.nixos.org/options](https://search.nixos.org/options).
- Les options sont typées : une faute de frappe dans un nom (`services.opensh`) fait échouer la construction au lieu d'être ignorée.
- Plusieurs modules peuvent remplir la même liste (`environment.systemPackages`) : les valeurs s'additionnent.

## Lire le dépôt, fichier par fichier

### `flake.nix` : le point d'entrée

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  sops-nix = {
    url = "github:Mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  hermes-agent.url = "github:NousResearch/hermes-agent";
};
```

- `inputs` : les dépendances du flake. `nixos-26.05` est la branche stable de NixOS, qui reçoit les correctifs de sécurité pendant environ sept mois. disko partitionne, sops-nix déchiffre les [secrets](secrets.md), hermes-agent fournit le paquet et le module de l'agent du club.
- `follows` : disko et sops-nix ont eux-mêmes besoin de nixpkgs ; on leur impose le nôtre, pour n'avoir qu'une seule version de nixpkgs en jeu. Hermes garde le sien (`nixos-unstable`), sur lequel ses paquets Python sont construits et testés ([ADR-0003](decisions/0003-hermes-service-natif.md)).

```nix
outputs = { self, nixpkgs, disko, sops-nix, hermes-agent, ... }: {
  nixosConfigurations.evo-serv1 = nixpkgs.lib.nixosSystem {
    modules = [
      disko.nixosModules.disko
      sops-nix.nixosModules.sops
      hermes-agent.nixosModules.default
      ./hosts/evo-serv1/configuration.nix
      { system.configurationRevision = self.rev or self.dirtyRev or null; }
    ];
  };
};
```

- `outputs` est une fonction : elle reçoit les inputs téléchargés (et `self`, le flake lui-même) et rend ce que le flake fournit.
- `nixosConfigurations.<nom>` : une machine. Pour en ajouter une, on ajoute une entrée avec son propre dossier dans `hosts/`.
- `modules` : les modules des inputs (qui ajoutent les options `disko.*`, `sops.*`, `services.hermes-agent.*`), la configuration de la machine, et un module d'une ligne qui grave dans le système le commit dont il vient (suffixé `-dirty` si le clone avait des modifications non commitées). `nixos-version --configuration-revision` l'affiche.

### `flake.lock` : les versions figées

Généré, jamais édité à la main. `nix flake update` le met à jour (dans une PR dédiée, voir [AGENTS.md](../AGENTS.md)) ; c'est l'équivalent d'un `apt upgrade` relisible.

### `hosts/evo-serv1/configuration.nix` : la machine

Le fichier commence par `{ ... }:` : c'est un module, donc une fonction qui reçoit les arguments de NixOS (ici, aucun n'est utilisé). Il importe les deux autres fichiers de la machine, puis fixe des options, groupées par thème :

| Bloc | Ce qu'il fait |
|---|---|
| `boot.loader.systemd-boot` | chargeur de démarrage UEFI ; `configurationLimit = 10` garde dix générations au menu, pour ne pas remplir la partition EFI |
| `boot.initrd.systemd.enable`, `security.tpm2.enable` | l'initrd (le mini-système qui démarre avant le vrai) utilise systemd, seul capable de lire la clé LUKS dans le TPM |
| `networking.useNetworkd`, `systemd.network.networks` | réseau par systemd-networkd : DHCP sur toute interface Ethernet, quel que soit son nom |
| `time.timeZone`, `i18n`, `console.keyMap` | heure de Paris, français, clavier AZERTY sur la console |
| `zramSwap.enable` | swap compressé en mémoire, sans partition ([ADR-0002](decisions/0002-disques-evo-serv1.md)) |
| `services.btrfs.autoScrub`, `services.fstrim` | vérification mensuelle des données btrfs, TRIM hebdomadaire des SSD |
| `services.openssh` | SSH par clé uniquement, sans connexion root |
| `users.mutableUsers = false`, `users.users.<nom>` | les comptes n'existent que par ce fichier : un `useradd` ou un `passwd` fait à la main disparaît au prochain `switch` |
| `security.sudo.wheelNeedsPassword = false` | les comptes n'ayant pas de mot de passe, `sudo` repose sur la clé SSH |
| `nix.settings`, `nix.gc` | active les flakes ; supprime chaque semaine les générations de plus de 30 jours |
| `programs.git.enable` | installe git : on déploie depuis un clone du dépôt, et un flake ne lit que les fichiers suivis par git |
| `system.stateVersion` | voir le piège ci-dessous |

### `hosts/evo-serv1/disko.nix` : les disques

disko décrit les partitions, le chiffrement et les systèmes de fichiers ; la même description sert à **créer** les disques à l'installation et à les **monter** à chaque démarrage. Pourquoi ce plan : [ADR-0002](decisions/0002-disques-evo-serv1.md).

- Le fichier commence par un `let … in` qui définit une petite fonction `luks` : les trois disques sont chiffrés de la même façon, on n'écrit cette configuration qu'une fois.
- `device = "/dev/disk/by-path/…"` désigne un disque par le port de la carte mère. Ce nom ne sert qu'à l'installation ; ensuite, NixOS retrouve les partitions par leur étiquette (`/dev/disk/by-partlabel/disk-system-system`, etc.), que disko a écrite.
- `passwordFile = "/tmp/luks-install.key"` : la clé de chiffrement provisoire, tapée une fois à l'installation, remplacée ensuite par le TPM et une clé de secours ([installation, étape 7](installer-evo-serv1.md#7-inscrire-le-tpm-et-la-clé-de-secours)).
- `crypttabExtraOpts = [ "tpm2-device=auto" ]` : au démarrage, essayer d'abord la clé scellée dans le TPM.
- Les `subvolumes` btrfs (`@root`, `@nix`, `@var`, `@home`) sont des dossiers d'un même système de fichiers montés à des endroits différents : ils partagent la place du disque, sans taille fixe à choisir.

### `hosts/evo-serv1/hardware.nix` : le matériel

Généré sur la machine par `nixos-generate-config --no-filesystems --show-hardware-config` : modules du noyau nécessaires au démarrage (NVMe, AHCI, USB), virtualisation, microcode Intel. On ne l'édite pas ; on le régénère si le matériel change. `--no-filesystems` parce que les montages viennent de disko.

## Les commandes du quotidien

À lancer sur la machine, depuis une copie du dépôt :

| Commande | Effet |
|---|---|
| `sudo nixos-rebuild switch --flake .` | construit et bascule tout de suite |
| `sudo nixos-rebuild boot --flake .` | construit, bascule au prochain démarrage (plus prudent pour un changement de noyau) |
| `sudo nixos-rebuild test --flake .` | bascule sans créer d'entrée au menu : un redémarrage annule tout |
| `nixos-rebuild build --flake .` | construit seulement, pour vérifier que ça compile |
| `sudo nixos-rebuild switch --rollback` | revient à la génération précédente |
| `nixos-rebuild list-generations` | liste les générations |
| `nix flake update` | met à jour `flake.lock` (dans une PR dédiée) |

Sans Nix sur son poste, on vérifie une modification avant la PR avec la commande d'évaluation d'[AGENTS.md](../AGENTS.md), lancée sur la machine ou depuis une clé NixOS.

## Ajouter un service

Un service se décrit dans `modules/services/<service>.nix`, puis la machine l'importe :

```nix
# modules/services/exemple.nix
{ ... }:
{
  services.uptime-kuma.enable = true;
}
```

```nix
# hosts/evo-serv1/configuration.nix
imports = [
  ./disko.nix
  ./hardware.nix
  ../../modules/services/exemple.nix
];
```

Avant d'écrire un service à la main ou en conteneur, chercher s'il existe déjà un module NixOS (`services.<nom>` sur [search.nixos.org/options](https://search.nixos.org/options)) : la plupart des logiciels courants en ont un, qui gère l'utilisateur système, le service systemd et les dossiers de données. Ses secrets passent par sops-nix, jamais en clair dans ce dépôt public.

## Les pièges

- **`system.stateVersion` n'est pas la version de NixOS.** Il dit avec quelle version les données des services ont été créées (format d'une base, emplacement d'un dossier). On ne le change jamais lors d'une mise à jour, même si NixOS passe en 26.11.
- **Un fichier nouveau doit être suivi par git.** Un flake ne voit que les fichiers connus de git : `git add` avant `nixos-rebuild`, sinon « file not found ».
- **Une modification faite à la main sur la machine est temporaire.** Éditer `/etc/…` ne marche pas (fichiers en lecture seule) ou disparaît au prochain `switch` : tout passe par ce dépôt et une PR.
- **Le store grossit.** Chaque génération garde ses paquets. Le ramasse-miettes (`nix.gc`) fait le ménage ; `sudo nix-collect-garbage -d` le force.

## Pour aller plus loin

- [nix.dev](https://nix.dev) : tutoriels officiels, à commencer par « Nix language basics ».
- [NixOS Manual](https://nixos.org/manual/nixos/stable/) : référence du système.
- [disko](https://github.com/nix-community/disko) : exemples de plans de disques.
- [Zero to Nix](https://zero-to-nix.com) : introduction aux flakes.
