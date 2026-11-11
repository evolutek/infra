# Choisir le système des serveurs

`evo-serv1` tourne aujourd'hui sous NixOS, [à l'essai](decisions/0001-nixos.md). **Le système définitif se décide par un vote entre Alpine, Debian, NixOS et openSUSE MicroOS.** Cette page donne les éléments pour voter ; les modalités du vote restent à fixer.

## Ce qui ne dépend pas du vote

Quel que soit le système, les services tournent en conteneurs rootless, suivant les [règles de sécurité de l'hôte](securite-hote.md#règles-des-conteneurs). Ils restent ainsi déplaçables d'un système à l'autre.

## Comparaison

| Critère ([pourquoi](securite-hote.md#critères-pour-choisir-le-système)) | Alpine | Debian | NixOS | openSUSE MicroOS |
|---|---|---|---|---|
| Support d'une version ([relevé](https://endoflife.date/) du 2026-10-30) | 2 ans : 3.24 jusqu'au 2028-06-01 | 13 jusqu'au 2030-06-30, puis LTS jusqu'en 2035 | environ 7 mois : 26.05 jusqu'au 2026-12-31 | pas de fin : mise à jour en continu ([relevé](https://get.opensuse.org/microos/) du 2026-11-11) |
| Changer de version | tous les 2 ans | tous les 2 à 5 ans | deux fois par an, à la main | jamais : les nouvelles versions arrivent par les mises à jour, avec des changements plus fréquents |
| Correctifs automatiques | `apk-autoupdate`, à scripter avec le redémarrage | `unattended-upgrades`, éprouvé | `system.autoUpgrade`, à mettre en place | fournis : `transactional-update` chaque jour, puis redémarrage planifié |
| Si une mise à jour casse | réparation à la main, au local ; un retour automatique est possible mais à construire (instantanés btrfs, chargeur de démarrage, contrôle de santé), sans outil officiel | réparation à la main, au local | retour à la version précédente au démarrage, choisi à la main | **retour automatique** à l'instantané précédent si le système ne démarre pas correctement (`health-checker`) |
| Disques chiffrés, déverrouillés par le TPM | clevis et initramfs modifié à la main, fragile aux mises à jour | possible, à tester | en place et testé | possible, à tester |
| Où vit la configuration | fichiers de conteneurs et scripts dans ce dépôt ; la machine peut s'en écarter | idem | la machine entière dans ce dépôt, relue par PR | idem Alpine, plus un fichier de premier démarrage (Ignition ou Combustion) |
| Reprendre la machine | facile : système simple, peu de choses installées | facile : le plus répandu | demande d'apprendre le langage Nix | demande d'apprendre ses réflexes : système en lecture seule, modifications par transaction et redémarrage, SELinux |
| Mémoire du système seul | la plus faible | moyenne | moyenne, plus le disque du store | 1 Go minimum, 2 Go recommandés ; 5 Go pour le système et 5 Go pour `/var` |

Pour MicroOS, une variante à version fixe existe : openSUSE Leap Micro, avec 24 mois de support par version depuis Leap Micro 6.2 ([cycle de vie](https://en.opensuse.org/Lifetime)). On change alors de version à la main, et on garde les mises à jour et le retour automatiques.

## Ce qui se passe après le vote

- **NixOS retenu :** on garde les fichiers Nix de ce dépôt.
- **Alpine, Debian ou MicroOS retenu :** on retire les fichiers Nix (`flake.nix`, `flake.lock`, `hosts/`, `modules/`, `docs/comprendre-nixos.md`), on réécrit la procédure d'installation et le déploiement, et on réinstalle la machine.
- **Dans les deux cas :** un nouvel ADR note le résultat et remplace l'[ADR-0001](decisions/0001-nixos.md).

Ce choix se fait de préférence avant la fin du support de NixOS 26.05, pour éviter de changer de version pour rien.
