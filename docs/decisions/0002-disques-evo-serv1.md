---
adr: 0002
title: Disques d'evo-serv1 sans miroir, chiffrés par LUKS et déverrouillés par le TPM
status: accepted
date: 2026-10-30
scope: framing
supersedes: []
superseded-by: []
---

# ADR-0002 — Disques d'evo-serv1 sans miroir, chiffrés par LUKS et déverrouillés par le TPM

## Context and Problem Statement
[`evo-serv1`](../evo-serv1.md) a trois disques de tailles et de natures différentes : un NVMe de 256 Go, un SSD SATA de 256 Go et un disque dur de 1 To. Il tourne H24 dans le local du club, sans personne devant, et doit redémarrer seul après une coupure. Pendant l'[étape 1](../etape-1-agent-public.md), il ne garde aucune donnée réelle, mais déjà des secrets, et il pourrait ensuite porter des données de membres : un disque emporté ne doit rien révéler. Un NAS du club est prévu à terme pour les données.

Il faut décider à quoi sert chaque disque, s'il faut de la redondance, et comment chiffrer.

## Considered Options

**Rôle des disques**

| Option | Pour | Contre |
|---|---|---|
| Miroir (RAID 1) NVMe + SSD pour le système | survit à la panne d'un disque sans arrêt | perd un disque entier ; protège un système qui se reconstruit déjà depuis ce dépôt |
| **Un rôle par disque** : système sur le NVMe, données vives puis cache du NAS sur le SSD, sauvegardes locales sur le disque dur | toute la capacité sert ; chaque disque fait ce pour quoi il est rapide ou grand | la panne du NVMe arrête la machine le temps de le remplacer et de réinstaller |

**Chiffrement**

| Option | Pour | Contre |
|---|---|---|
| Chiffrement matériel Opal du NVMe (SED) | aucun coût processeur | firmware non auditable, failles publiées sur des SED du marché (Meijer et van Gastel, « Self-encrypting deception », 2018) ; ne couvre pas les disques SATA |
| **LUKS sur les trois disques** | logiciel libre et auditable ; même méthode partout ; AES-NI rend le coût négligeable sur l'i5-9400 | une clé à fournir au démarrage |

**Déverrouillage**

| Option | Pour | Contre |
|---|---|---|
| Phrase de passe tapée à chaque démarrage | rien n'est stocké sur la machine | la machine reste bloquée après une coupure de courant, sans personne au local |
| **TPM 2.0** (`systemd-cryptenroll`), plus une clé de secours rangée hors de la machine | redémarrage seul ; un disque sorti de la machine reste illisible | sans Secure Boot, une personne qui démarre un système modifié sur la machine peut obtenir la clé |

**Système de fichiers du NVMe** : btrfs, plutôt qu'ext4 en partitions séparées, pour que `/`, `/nix`, `/var` et `/home` partagent la place sans tailles à deviner, avec la compression et des instantanés possibles.

**Swap** : zram (swap compressé en RAM), plutôt qu'une partition de swap qui demanderait son propre volume chiffré et userait le SSD.

## Decision Outcome
Chosen options: **un rôle par disque, LUKS partout, déverrouillage par le TPM avec une clé de secours**, because le système se reconstruit depuis ce dépôt en moins d'une heure ([ADR-0001](0001-nixos.md)) et les données vivront sur le NAS : un miroir ne protégerait que ce temps d'arrêt, au prix d'un disque entier. Le TPM est le seul moyen de chiffrer tout en redémarrant sans personne.

Le plan précis est dans [`hosts/evo-serv1/disko.nix`](../../hosts/evo-serv1/disko.nix) et résumé dans la [fiche de la machine](../evo-serv1.md#disques).

### Consequences
- Good, because un disque volé ou mis au rebut ne révèle rien, et les trois disques se gèrent de la même façon.
- Good, because toute la capacité sert, et le SSD pourra devenir cache local du NAS (NFS + FS-Cache) sans repartitionner.
- Bad, because la panne du NVMe arrête les services jusqu'à son remplacement, et **pendant l'étape 1 il n'y a aucune sauvegarde hors machine** : ce qui est dans `/srv` est alors perdu, ce qui est [accepté tant qu'on teste](../etape-1-agent-public.md#sans-nas-donc-sans-sauvegarde).
- Bad, because sans Secure Boot, le scellement TPM protège un disque emporté mais pas la machine entière ; [lanzaboote](https://github.com/nix-community/lanzaboote) est prévu pour le renforcer.
- Neutral: la clé de secours doit être rangée par le club (gestionnaire de mots de passe à venir).
- Neutral: le déverrouillage décrit ici est celui de NixOS (`systemd-cryptenroll`) ; il est à revoir si le [vote sur le système](../choix-du-systeme.md) en retient un autre.
