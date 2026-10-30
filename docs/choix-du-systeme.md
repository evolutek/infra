# Choisir le système des serveurs

`evo-serv1` tourne aujourd'hui sous NixOS, [à l'essai](decisions/0001-nixos.md). **Le système définitif se décide par un vote entre Alpine, Debian et NixOS.** Cette page donne les éléments pour voter ; les modalités du vote restent à fixer.

## Ce qui ne dépend pas du vote

Quel que soit le système, les services tournent en conteneurs rootless, suivant les [règles de sécurité de l'hôte](securite-hote.md#règles-des-conteneurs). Ils restent ainsi déplaçables d'un système à l'autre.

## Comparaison

| Critère ([pourquoi](securite-hote.md#critères-pour-choisir-le-système)) | Alpine | Debian | NixOS |
|---|---|---|---|
| Support d'une version ([relevé](https://endoflife.date/) du 2026-10-30) | 2 ans : 3.24 jusqu'au 2028-06-01 | 13 jusqu'au 2030-06-30, puis LTS jusqu'en 2035 | environ 7 mois : 26.05 jusqu'au 2026-12-31 |
| Changer de version | tous les 2 ans | tous les 2 à 5 ans | deux fois par an, à la main |
| Correctifs automatiques | `apk-autoupdate`, à scripter avec le redémarrage | `unattended-upgrades`, éprouvé | `system.autoUpgrade`, à mettre en place |
| Si une mise à jour casse | réparation à la main, au local | réparation à la main, au local | retour à la version précédente au démarrage |
| Disques chiffrés, déverrouillés par le TPM | clevis et initramfs modifié à la main, fragile aux mises à jour | possible, à tester | en place et testé |
| Où vit la configuration | fichiers de conteneurs et scripts dans ce dépôt ; la machine peut s'en écarter | idem | la machine entière dans ce dépôt, relue par PR |
| Reprendre la machine | facile : système simple, peu de choses installées | facile : le plus répandu des trois | demande d'apprendre le langage Nix |
| Mémoire du système seul | la plus faible | moyenne | moyenne, plus le disque du store |

## Ce qui se passe après le vote

- **NixOS retenu :** on garde les fichiers Nix de ce dépôt.
- **Alpine ou Debian retenue :** on retire les fichiers Nix (`flake.nix`, `flake.lock`, `hosts/`, `modules/`, `docs/comprendre-nixos.md`), on réécrit la procédure d'installation et le déploiement, et on réinstalle la machine.
- **Dans les deux cas :** un nouvel ADR note le résultat et remplace l'[ADR-0001](decisions/0001-nixos.md).

Ce choix se fait de préférence avant la fin du support de NixOS 26.05, pour éviter de changer de version pour rien.
