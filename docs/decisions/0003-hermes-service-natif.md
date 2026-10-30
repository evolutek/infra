---
adr: 0003
title: Hermes en service systemd natif pour le test de l'agent public, à réévaluer
status: proposed
date: 2026-10-30
scope: framing
supersedes: []
superseded-by: []
---

# ADR-0003 — Hermes en service systemd natif pour le test de l'agent public, à réévaluer

## Context and Problem Statement
L'agent du club ([EvoluBot](https://github.com/evolutek/EvoluBot)) tourne sur [`evo-serv1`](../evo-serv1.md) avec [Hermes Agent](https://github.com/NousResearch/hermes-agent). Il lit du contenu écrit par des inconnus et peut être détourné par *prompt injection* : ce qu'il peut faire sur la machine doit être limité ([sécurité de l'hôte](../securite-hote.md)).

L'[ADR-0001](0001-nixos.md) supposait que Hermes n'avait pas de paquet Nix et qu'il faudrait maintenir ici une image de conteneur. Ce n'est plus vrai : le dépôt de Hermes fournit un flake avec un paquet et un module NixOS (`nix/nixosModules.nix`), qui a deux modes.

Il faut choisir comment le faire tourner. Cette étape ne porte que sur l'[agent public](../etape-1-agent-public.md), mais la décision prise avec le club est d'avoir deux agents séparés, public et administration ([EvoluBot#26](https://github.com/evolutek/EvoluBot/issues/26)), ce que ce choix doit pouvoir suivre.

## Considered Options

| Option | Pour | Contre |
|---|---|---|
| **Module officiel, mode natif** : service systemd sous un utilisateur système `hermes`, durci par ce dépôt | paquet et module maintenus par Hermes ; mise à jour par `flake.lock`, sans image à reconstruire ; secrets par sops-nix prévus par le module | le système de fichiers de l'hôte est visible en lecture ; les tâches cron sortent du bac à sable de l'unité (voir les conséquences) |
| Image officielle de Hermes (`nousresearch/hermes-agent`) sous Podman rootless | maintenue par l'amont, utilisateur non root, données dans un seul volume ; un agent ne voit que ses volumes ; portable hors de NixOS | l'init démarre en root pour régler les droits du volume, et le mode rootless n'est pas documenté ; l'image embarque Chromium ; fonctionnement des tâches cron à vérifier |
| Notre conteneur Podman rootless, image construite par Nix depuis le paquet Hermes | isolation plus forte du système de fichiers ; suit à la lettre les [règles des conteneurs](../securite-hote.md#règles-des-conteneurs) | un module entier à écrire et à maintenir ici, à côté de celui de Hermes, qu'on n'utiliserait plus |
| Module officiel, mode conteneur | le plus simple à brancher | root dans le conteneur ; `apt` et `curl \| sh` au premier démarrage ; `sudo` sans mot de passe pour l'agent, « pour qu'il se modifie lui-même » : contraire à toutes nos règles |

## Decision Outcome
Chosen option: **module officiel, mode natif, pour l'étape 1**, because il réutilise le travail de Hermes au lieu de le refaire, et parce que la vraie barrière contre un agent détourné n'est pas le conteneur mais l'absence d'outils pour agir sur la machine : les outils `terminal`, `code_execution`, `file`, `browser` et `computer_use` sont coupés pour toutes les sessions (`agent.disabled_toolsets`). L'agent agit par Discord et par ses serveurs MCP, pas par un shell.

Le service est décrit dans [`modules/services/hermes.nix`](../../modules/services/hermes.nix) ; ses données vont dans `/srv/hermes`.

**Ce choix est à réévaluer** avant le second agent, notamment avec l'image officielle ([#13](https://github.com/evolutek/infra/issues/13)) : à deux sur une machine, chaque agent ne doit voir ni les données ni les secrets de l'autre, et le dépôt doit rester relisible si le [vote sur le système](../choix-du-systeme.md) écarte NixOS.

### Consequences
- Good, because une mise à jour de Hermes est une PR qui change `flake.lock`, relisible et réversible comme le reste du système.
- Good, because l'unité ajoute au durcissement du module (`NoNewPrivileges`, `ProtectSystem=strict`) : aucune capability, `/home` caché, périphériques privés, noyau protégé, appels système filtrés (`@system-service`), mémoire plafonnée à 2 Go.
- Bad, because les tâches cron de Hermes passent par `systemd-run --user --scope`, sous le gestionnaire utilisateur de `hermes`, et non dans l'unité durcie. Seuls les outils coupés les limitent.
- Bad, because Hermes apporte son propre nixpkgs (`nixos-unstable`) : un second jeu de paquets dans le store, et des correctifs qui dépendent de la mise à jour de l'input `hermes-agent`.
- Bad, because en mode natif, le système de fichiers de l'hôte reste visible en lecture : c'est le point à régler avant un second agent.
- Neutral: si un outil `terminal` devient nécessaire, il tournera dans un bac à sable (Podman rootless, `terminal.backend: docker`), décidé par un nouvel ADR.
