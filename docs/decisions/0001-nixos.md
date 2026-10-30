---
adr: 0001
title: NixOS à l'essai sur evo-serv1, en attendant le vote sur le système
status: proposed
date: 2026-10-30
scope: framing
supersedes: []
superseded-by: []
---

# ADR-0001 — NixOS à l'essai sur evo-serv1, en attendant le vote sur le système

## Context and Problem Statement
[`evo-serv1`](../evo-serv1.md) tourne H24 au local du club, sans personne devant. Il sert d'abord à [tester l'agent public](../etape-1-agent-public.md), qui lit du contenu écrit par des inconnus. La sécurité de la machine repose donc sur les correctifs de l'hôte. Le système se choisit sur les [critères de sécurité de l'hôte](../securite-hote.md#critères-pour-choisir-le-système), et aussi sur la capacité du club à le reprendre quand ses administrateurs changent.

## Considered Options

| Option | Correctifs auto, noyau compris | Redémarrage sûr | Surface minimale | Rootless | Config relisible |
|---|---|---|---|---|---|
| Debian | Oui (`unattended-upgrades`) | Non | Oui | Oui | Non |
| Ubuntu Server | Oui (`unattended-upgrades`) | Non | Moyenne (snapd, cloud-init) | Oui | Non |
| Arch | Déconseillé (rolling, intervention manuelle parfois nécessaire) | Non, sauf snapshots Btrfs | Oui | Oui | Non |
| Gentoo | Difficile (compilation de chaque mise à jour) | Non | Oui | Oui | Non |
| Alpine, tout en conteneurs | À scripter (`apk upgrade` + redémarrage) | Non | Très faible | Oui | Services seulement (`compose.yaml`) |
| NixOS | À mettre en place (`system.autoUpgrade`) | Oui (générations) | Oui (seul ce qui est déclaré) | Oui | Oui (hôte entier) |

- **Ubuntu Server, Arch et Gentoo** sont écartés : surface plus large pour le premier, maintenance trop lourde pour les deux autres.
- **Debian, Alpine et NixOS** restent en lice. La comparaison détaillée, dont la durée de support, est dans [choisir le système](../choix-du-systeme.md).

## Decision Outcome
Chosen option: **NixOS pour l'étape 1, à l'essai**, because il est déjà installé et testé sur la machine, et le choix n'engage pas la suite : les services sont destinés à tourner en conteneurs, déplaçables d'un système à l'autre.

**Le système définitif se décide par un vote entre Alpine, Debian et NixOS.** Selon le résultat, on garde les fichiers Nix, ou on les retire et on réinstalle la machine. Un nouvel ADR note alors le résultat et remplace celui-ci.

### Consequences
- Good, because la machine se reconstruit à l'identique depuis le dépôt si elle est remplacée.
- Good, because la configuration de l'hôte se relit et se valide par PR, comme le reste du dépôt.
- Good, because une mise à jour ratée se répare par un retour à la génération précédente, au démarrage.
- Bad, because une version de NixOS n'est suivie qu'environ 7 mois : 26.05 s'arrête le 2026-12-31, et changer de version est un geste manuel, deux fois par an.
- Bad, because NixOS demande d'apprendre le langage Nix à qui maintient la machine, et un seul administrateur le sait aujourd'hui.
- Bad, because l'installateur officiel de Hermes et `hermes update` ne marchent pas tels quels : ils posent des binaires précompilés qui cherchent des bibliothèques aux chemins habituels. Il faut passer par le module NixOS de Hermes ou par son image officielle.
- Neutral: chaque génération conservée occupe du stockage ; son dimensionnement est dans la [fiche de la machine](../evo-serv1.md#stockage).
