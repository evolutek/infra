# Gérer les secrets

Les secrets des machines sont chiffrés dans `secrets/<machine>.yaml` par [sops](https://github.com/getsops/sops), et déchiffrés au démarrage par [sops-nix](https://github.com/Mic92/sops-nix) vers `/run/secrets/`. Pourquoi ce choix : [ADR-0004](decisions/0004-secrets-sops-nix.md).

Qui peut déchiffrer : les destinataires listés dans [`.sops.yaml`](../.sops.yaml), c'est-à-dire chaque machine et chaque administrateur.

## Préparer son poste

Installer `sops` (3.10 ou plus). La clé SSH ed25519 de l'administrateur sert de clé de déchiffrement ; si ce n'est pas `~/.ssh/id_ed25519`, l'indiquer :

```sh
export SOPS_AGE_SSH_PRIVATE_KEY_FILE=~/.ssh/<sa clé>
```

## Modifier un secret

```sh
sops secrets/evo-serv1.yaml
```

`sops` ouvre le fichier en clair dans l'éditeur (`$EDITOR`) et le rechiffre à la fermeture. À lancer dans son propre terminal : un secret ne doit passer ni par un outil qui garde un historique, ni par une conversation. Puis commit, PR, et déploiement : le service reçoit la nouvelle valeur au `switch`.

Le fichier est un YAML ; une clé imbriquée devient un nom avec des `/` dans la configuration :

```yaml
hermes:
  env: |
    DISCORD_BOT_TOKEN=…
```

se déclare `sops.secrets."hermes/env" = { };` et se lit à `config.sops.secrets."hermes/env".path`. Un secret se passe toujours par ce chemin, jamais par sa valeur : une valeur passée à Nix finit dans `/nix/store`, lisible par tous.

Un secret appartient à `root` par défaut. Un service qui le lit sous un autre compte le déclare avec `owner`, par exemple un conteneur rootless, dont `podman` lit le fichier d'environnement sous l'utilisateur du conteneur : `sops.secrets."omniroute/env".owner = "omniroute";`.

## Ajouter un administrateur

1. Ajouter sa clé SSH publique (`ssh-ed25519 AAAA…`, sans commentaire) dans `keys:` de `.sops.yaml`, et son alias dans chaque `key_groups` concerné.
2. Rechiffrer pour la nouvelle liste, depuis le poste d'un administrateur existant :
   ```sh
   sops updatekeys secrets/evo-serv1.yaml
   ```
3. PR. Pour retirer quelqu'un, même chemin, puis **changer les secrets** qu'il a pu lire : l'ancienne version du fichier reste dans l'historique git.

## Ajouter ou réinstaller une machine

Sa clé age se dérive de sa clé d'hôte SSH, sur la machine :

```sh
nix shell nixpkgs#ssh-to-age -c ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
```

La mettre dans `.sops.yaml` (une réinstallation remplace l'ancienne), puis `sops updatekeys` comme ci-dessus. Au déploiement, `sops-install-secrets` affiche la clé qu'il a importée : elle doit être celle de `.sops.yaml`.
