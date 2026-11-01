---
adr: 0007
title: Le banc d'essai des modèles tourne sur evo-serv1, code des modèles compris
status: proposed
date: 2026-11-01
scope: framing
supersedes: []
superseded-by: []
---

# ADR-0007 — Le banc d'essai des modèles tourne sur evo-serv1, code des modèles compris

## Context and Problem Statement
Le [banc d'essai](https://github.com/evolutek/EvoluBot/blob/docs/llm-benchmark/bench/README.md) compare les modèles gratuits servis par OmniRoute, sur des données fictives. Les quotas des fournisseurs l'étalent sur des semaines : sur le poste d'un administrateur, il s'arrête à chaque extinction ou changement de réseau.

Son thème G exécute du code écrit par ces modèles, pour le noter. Le faire sur [`evo-serv1`](../evo-serv1.md), c'est l'exécuter sur la machine qui héberge OmniRoute et ses clés de fournisseurs.

## Considered Options

| Option | Pour | Contre |
|---|---|---|
| **Tout le banc sur `evo-serv1`** | tourne en continu sans personne ; OmniRoute est local ; un seul endroit à suivre | du code non fiable s'exécute sur le serveur |
| Le banc sur `evo-serv1`, le thème G sur un poste | aucun code de modèle sur le serveur | deux lancements à suivre, et le thème G reste soumis aux arrêts du poste |
| Tout le banc sur le poste d'un administrateur | rien à changer sur le serveur | s'arrête à chaque extinction ; le code des modèles tourne à côté des fichiers de la personne |
| Une machine ou un conteneur à part | isolation la plus forte | aucune autre machine disponible pendant l'étape 1 |

## Decision Outcome
Chosen option: **tout le banc sur `evo-serv1`**, because la machine ne porte aucune donnée réelle pendant l'[étape 1](../etape-1-agent-public.md) et que ce qu'on y perdrait se refait : les clés de fournisseurs se révoquent et la machine se réinstalle depuis ce dépôt.

Le service est décrit dans [`modules/services/bench.nix`](../../modules/services/bench.nix). Deux barrières séparent le code des modèles du reste :

- le **bac à sable du banc** (`bubblewrap`) : ni réseau, ni fichiers hors de son dossier de travail et du système en lecture seule, avec limites de temps, de mémoire et de CPU ;
- le **service systemd** : utilisateur dédié sans accès aux secrets d'OmniRoute ni de Hermes, système de fichiers en lecture seule hors de `/srv/bench`, mémoire plafonnée à 3 Go.

**Cette décision ne vaut que pendant l'étape 1.** Elle est à revoir avant qu'une donnée réelle arrive sur la machine.

### Consequences
- Good, because le banc avance sans dépendre du poste de quelqu'un, et le résultat est relisible et reproductible par ce dépôt.
- Bad, because une faille de `bubblewrap` ou du noyau donnerait au code d'un modèle un accès à la machine sous l'utilisateur `bench`, voire plus.
- Bad, because le service a besoin de créer des espaces de noms et de monter `/proc` : il se passe donc de `RestrictNamespaces`, `ProtectKernelTunables`, `ProtectKernelLogs` et `ProtectHostname`, et sa note `systemd-analyze security` est moins bonne que celle de Hermes.
- Bad, because `npx` télécharge promptfoo depuis npm au premier lancement : la version est fixée, pas son contenu. Le paquet de nixpkgs est trop ancien pour garder la version avec laquelle le banc a commencé.
- Neutral: le banc consomme de la mémoire et les quotas des fournisseurs ; à couper ou réduire quand Hermes s'active ([#6](https://github.com/evolutek/infra/issues/6)).
