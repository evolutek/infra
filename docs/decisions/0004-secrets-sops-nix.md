---
adr: 0004
title: Secrets chiffrés dans le dépôt par sops-nix, pour la machine et pour chaque administrateur
status: accepted
date: 2026-10-30
scope: framing
supersedes: []
superseded-by: []
---

# ADR-0004 — Secrets chiffrés dans le dépôt par sops-nix, pour la machine et pour chaque administrateur

## Context and Problem Statement
Les services ont besoin de secrets (jeton du bot Discord, clés d'API). Ce dépôt est public, et tout ce que Nix construit atterrit dans `/nix/store`, lisible par tous les utilisateurs de la machine. Un secret ne peut donc être ni écrit en clair ici, ni passé à Nix comme une valeur. Il faut aussi qu'evo-serv1 redémarre sans personne, et que le club ne perde pas ses secrets si un administrateur s'en va.

## Considered Options

| Option | Pour | Contre |
|---|---|---|
| Fichier d'environnement posé à la main sur la machine, hors dépôt | rien à apprendre | invisible en revue ; perdu avec la machine ; une modification à la main que NixOS ne connaît pas |
| agenix | simple ; clés SSH directement | un fichier par secret ; édition moins pratique ; moins répandu |
| **sops-nix** | un fichier YAML chiffré par machine, versionné et relu par PR (on voit quelles clés changent, pas leur valeur) ; déchiffré au démarrage vers `/run/secrets`, hors du store ; destinataires multiples | un outil de plus à installer (`sops`) pour éditer |

## Decision Outcome
Chosen option: **sops-nix**, chaque fichier chiffré pour deux sortes de destinataires, listés dans [`.sops.yaml`](../../.sops.yaml) :

- **la machine**, par une clé age dérivée de sa clé d'hôte SSH (`/etc/ssh/ssh_host_ed25519_key`) : elle déchiffre seule au démarrage ;
- **chaque administrateur**, par sa clé SSH ed25519 publique, que `sops` (3.10 et plus) accepte directement : pas de nouvelle clé à gérer.

La marche à suivre est dans [secrets.md](../secrets.md).

### Consequences
- Good, because les secrets sont sauvegardés avec le dépôt, chiffrés, et une machine réinstallée les retrouve dès qu'elle est ajoutée aux destinataires.
- Good, because ajouter ou retirer un administrateur est une PR (`sops updatekeys`).
- Bad, because une clé d'administrateur volée ouvre tous les secrets : elle doit avoir une phrase de passe. Retirer une personne ne suffit pas, il faut aussi changer les secrets qu'elle a pu lire.
- Bad, because réinstaller une machine change sa clé d'hôte : il faut mettre sa nouvelle clé dans `.sops.yaml` avant qu'elle puisse déchiffrer.
- Neutral: tant qu'il n'y a qu'un administrateur, la machine est le seul autre destinataire ; un second administrateur est à ajouter.
- Neutral: `sops-nix` n'existe que sur NixOS. Si le [vote sur le système](../choix-du-systeme.md) en retient un autre, le fichier chiffré et `sops` restent, mais le déchiffrement au démarrage est à refaire.
