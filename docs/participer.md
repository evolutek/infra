# Participer

Ce que chaque membre du club peut faire pour les serveurs de l'association, et comment devenir administrateur. Ce qu'ils hébergent : [README](../README.md).

## Sans accès à la machine

Tout se passe sur GitHub, et c'est ouvert à tous les membres :

- **Lire** : ce dépôt décrit la machine en entier, rien n'est caché ailleurs à part les secrets. Pour démarrer : [comprendre NixOS avec ce dépôt](comprendre-nixos.md), puis la [fiche d'`evo-serv1`](evo-serv1.md).
- **Proposer** : une idée, un besoin ou un bug devient une [issue](https://github.com/evolutek/infra/issues). Ce que l'agent du club doit savoir faire se propose dans [EvoluBot](https://github.com/evolutek/EvoluBot/issues).
- **Relire** : `main` n'accepte une PR qu'avec **deux approbations**. Relire les [PR ouvertes](https://github.com/evolutek/infra/pulls) est l'aide la plus utile, même sans connaître NixOS : une question sur ce qui n'est pas clair améliore la doc.
- **Modifier** : fork ou branche, puis PR, en suivant les [règles du dépôt](../AGENTS.md). Le dépôt est public : jamais de secret, d'adresse IP, de numéro de série ni de nom de personne.

## Devenir administrateur

Un administrateur se connecte à la machine, déploie et lit les secrets. Le bureau décide qui l'est.

1. **Une clé SSH ed25519** sur son poste, protégée par une phrase de passe : `ssh-keygen -t ed25519`.
2. **Une PR qui ajoute sa clé publique** (`~/.ssh/<sa clé>.pub`, sans le commentaire de fin) à deux endroits :
   - `openssh.authorizedKeys.keys` du compte `grand-conseil`, dans [`hosts/evo-serv1/configuration.nix`](../hosts/evo-serv1/configuration.nix) ;
   - `.sops.yaml`, pour pouvoir déchiffrer les secrets ([secrets.md](secrets.md#ajouter-un-administrateur)) ; un administrateur existant rechiffre ensuite les secrets.
3. **Le tailnet du club** : installer [Tailscale](https://tailscale.com/download) et s'y connecter avec le compte Google du club ([ADR-0005](decisions/0005-acces-distance-tailscale.md)).
4. Une fois la PR déployée, depuis n'importe où :
   ```sh
   ssh -i ~/.ssh/<sa clé> grand-conseil@evo-serv1
   ```
   Pour éviter de retaper `-i`, ajouter à `~/.ssh/config` :
   ```
   Host evo-serv1
       User grand-conseil
       IdentityFile ~/.ssh/<sa clé>
   ```

Ensuite : [déployer](../README.md#déployer), [administrer OmniRoute](omniroute.md), [gérer les secrets](secrets.md).

## Ce qu'il faut savoir avant d'y toucher

- **La machine se reconstruit depuis ce dépôt.** Une modification faite à la main sur la machine disparaît au prochain déploiement : tout passe par une PR.
- **Le tailnet et le compte `grand-conseil` sont partagés** : tout le monde y a les mêmes droits. Les clés SSH, elles, sont nominatives (le journal de `sshd` note l'empreinte de la clé utilisée) : on retire quelqu'un en retirant sa clé, puis en changeant les secrets qu'il a pu lire.
- **Une connexion lente n'est pas une panne.** Quand l'un des deux bouts est derrière un réseau mobile ou un NAT strict, Tailscale passe par un relais (`tailscale ping evo-serv1` affiche `via DERP`) : ça marche, en plus lent.
- **En cas de souci**, la génération précédente du système reste au menu de démarrage ; sur place, le SSH par le réseau local marche même si Tailscale est coupé.
