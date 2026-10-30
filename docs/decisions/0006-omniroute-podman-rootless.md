---
adr: 0006
title: OmniRoute dans un conteneur Podman rootless, image officielle épinglée
status: accepted
date: 2026-10-30
scope: framing
supersedes: []
superseded-by: []
---

# ADR-0006 — OmniRoute dans un conteneur Podman rootless, image officielle épinglée

## Context and Problem Statement
L'agent du club passe par [OmniRoute](https://github.com/diegosouzapw/OmniRoute) pour joindre les offres gratuites de plusieurs fournisseurs de modèles ([EvoluBot#9](https://github.com/evolutek/EvoluBot/issues/9)). OmniRoute n'a ni paquet nixpkgs ni module NixOS : son `flake.nix` ne fournit qu'un shell de développement. C'est une application Next.js publiée sur npm (461 Mo, 90 dépendances, des binaires natifs précompilés : `sharp`, `onnxruntime-node`, `better-sqlite3`, Playwright) et en image officielle `docker.io/diegosouzapw/omniroute`, qui tourne sous l'utilisateur `node`. Une version sort environ toutes les trois semaines. Il faut choisir comment la faire tourner sur [`evo-serv1`](../evo-serv1.md), qui n'a encore aucun conteneur.

## Considered Options

| Option | Pour | Contre |
|---|---|---|
| Paquet Nix maison (`buildNpmPackage`) en service natif, comme Hermes ([ADR-0003](0003-hermes-service-natif.md)) | pas de runtime de conteneurs ; durcissement par l'unité systemd | une dérivation à maintenir nous-mêmes : reconstruire Next.js depuis les sources (lourd avec 8 Go de RAM) ou patcher les binaires précompilés pour NixOS, à refaire à chaque version ; personne au club pour la reprendre |
| `npm install -g omniroute` sous une unité systemd | simple à écrire | contourne Nix : version et dépendances non reproductibles, absentes de la configuration relue par PR |
| Image officielle sous Docker | le chemin documenté par l'amont | démon root ; un accès au socket vaut root sur l'hôte |
| **Image officielle sous Podman rootless** | image maintenue par l'amont ; pas de démon root ; déclaré par `virtualisation.oci-containers` avec `podman.user` | premier conteneur de la machine : un runtime de plus à tenir à jour, et les bibliothèques de l'image à suivre séparément |

## Decision Outcome
Chosen option: **l'image officielle sous Podman rootless**, because c'est la seule qui suit l'amont sans demander au club de maintenir un paquetage, tout en respectant les [règles des conteneurs](../securite-hote.md#règles-des-conteneurs).

- Utilisateur système `omniroute` dédié, avec *linger* : le conteneur et son stockage d'images vivent sous ce compte. L'utilisateur `node` de l'image correspond à `omniroute` sur l'hôte (`--userns=keep-id`), qui possède seul `/srv/omniroute`.
- Image épinglée par **version et digest** : une mise à jour est un changement du digest dans ce dépôt, relu par PR, puis un déploiement.
- Port publié sur `127.0.0.1` seulement : Hermes est sur la même machine, et le tableau de bord d'administration se joint par un tunnel SSH.
- `--cap-drop=ALL`, `no-new-privileges`, racine en lecture seule, mémoire et nombre de processus bornés.
- `REQUIRE_API_KEY=true`, mot de passe du tableau de bord et clés de chiffrement par sops ; clés d'API et jetons des fournisseurs chiffrés champ par champ dans la base SQLite (`STORAGE_ENCRYPTION_KEY`) ; le reste de la base (historique, réglages) ne l'est pas, d'où une sauvegarde chiffrée ([#3](https://github.com/evolutek/infra/issues/3)).
- Relais « cloud » et pool de proxys gratuits fixés à désactivé, même si ce sont déjà les valeurs par défaut : un changement de défaut en amont ne doit pas faire passer les requêtes par un tiers.
- Configuration : [`modules/services/omniroute.nix`](../../modules/services/omniroute.nix).

### Consequences
- Good, because l'amont construit et publie l'image ; le club ne fait que choisir quand passer à la version suivante.
- Good, because une évasion du conteneur ne donne que l'utilisateur `omniroute`, sans droits sur le reste de la machine.
- Bad, because OmniRoute expose une large surface (tableau de bord, agents ACP, serveurs MCP) et a déjà eu une faille critique exploitable sans authentification ([CVE-2026-88062](https://github.com/diegosouzapw/OmniRoute/security/advisories/GHSA-hf57-cqmx-p4gr), corrigée en 3.8.49) : les avis de sécurité du dépôt amont sont à suivre, et l'instance reste dédiée à l'agent ([EvoluBot#9](https://github.com/evolutek/EvoluBot/issues/9)).
- Bad, because les bibliothèques de l'image ont leurs propres failles, qui ne se corrigent pas avec les mises à jour de NixOS : sans nouvelle version de l'amont, l'image vieillit.
- Neutral: cet ADR remplace, pour OmniRoute, l'idée d'un service natif retenue pour Hermes, elle-même à réévaluer ([#13](https://github.com/evolutek/infra/issues/13)).
- Neutral: la même image se reprend telle quelle si le [vote sur le système](../choix-du-systeme.md) écarte NixOS ; seule sa déclaration change.
- Neutral: la place d'OmniRoute avec deux agents, surtout sur deux machines, reste à décider : le service détient les clés des fournisseurs et voit tous les prompts ([EvoluBot#26](https://github.com/evolutek/EvoluBot/issues/26)).
