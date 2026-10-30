# infra

Les serveurs de l'association Evolutek et les services qu'ils hébergent, décrits en [NixOS](https://nixos.org) : chaque machine se reconstruit à l'identique depuis ce dépôt. Nouveau sur NixOS : commencer par [comprendre NixOS avec ce dépôt](docs/comprendre-nixos.md). Participer, devenir administrateur : [participer](docs/participer.md).

**Où on en est :** [étape 1, tester l'agent public](docs/etape-1-agent-public.md) sur une seule machine, sans NAS ni sauvegarde. NixOS y est à l'essai : le système définitif se [décide par un vote](docs/choix-du-systeme.md).

## Machines

| Machine | Matériel | Services | Doc |
|---|---|---|---|
| `evo-serv1` | Lenovo V530-15ICR, i5-9400, 8 Go | OmniRoute ; agent du club (prévu) | [fiche](docs/evo-serv1.md), [installation](docs/installer-evo-serv1.md) |

## Services

| Service | Machine | État | Suivi |
|---|---|---|---|
| Agent public du club ([Hermes Agent](https://github.com/NousResearch/hermes-agent)) | `evo-serv1` | [module](modules/services/hermes.nix) prêt, désactivé en attendant OmniRoute ([EvoluBot#9](https://github.com/evolutek/EvoluBot/issues/9)) ; choix : [ADR-0003](docs/decisions/0003-hermes-service-natif.md) | [EvoluBot](https://github.com/evolutek/EvoluBot), epic [#7](https://github.com/evolutek/EvoluBot/issues/7) |
| Passerelle LLM ([OmniRoute](https://github.com/diegosouzapw/OmniRoute)) | `evo-serv1` | [déployée](modules/services/omniroute.nix), sans fournisseur branché ; choix : [ADR-0006](docs/decisions/0006-omniroute-podman-rootless.md) ; [administration](docs/omniroute.md) | [EvoluBot#9](https://github.com/evolutek/EvoluBot/issues/9), [#29](https://github.com/evolutek/EvoluBot/issues/29) |
| Gestionnaire de mots de passe | hors de l'étape 1 | à choisir avec le bureau | issue #154 du vault du club (privé) |

## Organisation

| Chemin | Contenu |
|---|---|
| `flake.nix`, `flake.lock` | point d'entrée et versions figées de nixpkgs |
| `hosts/<machine>/` | ce qui est propre à une machine : disques (disko), matériel, configuration |
| `modules/services/<service>.nix` | un service, activable sur n'importe quelle machine |
| `secrets/<machine>.yaml`, `.sops.yaml` | secrets chiffrés d'une machine, et qui peut les déchiffrer |
| `docs/` | [étape en cours](docs/etape-1-agent-public.md), [choix du système](docs/choix-du-systeme.md), fiches des machines, procédures, [sécurité de l'hôte](docs/securite-hote.md), [décisions](docs/decisions/) |

Une machine porte un nom neutre (`evo-serv1`, `evo-serv2`…), jamais celui d'un service : un service peut changer de machine sans que rien ne soit renommé.

## Déployer

Sur la machine, chaque administrateur a sa copie du dépôt dans son dossier personnel :

```sh
git clone https://github.com/evolutek/infra.git ~/infra   # la première fois
cd ~/infra && git pull
sudo nixos-rebuild switch --flake .
```

Le nom d'hôte choisit la configuration (`nixosConfigurations.<nom>`). En cas de souci, la génération précédente reste au menu de démarrage.

## Secrets

Aucun secret en clair dans ce dépôt public : ils sont chiffrés par [sops-nix](https://github.com/Mic92/sops-nix) dans `secrets/`, pour chaque machine et chaque administrateur. Les modifier, ajouter un administrateur : [secrets.md](docs/secrets.md). Les règles complètes sont dans [AGENTS.md](AGENTS.md).

## Licence

MIT - Association Evolutek
