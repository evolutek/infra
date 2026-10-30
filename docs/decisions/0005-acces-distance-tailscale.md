---
adr: 0005
title: Maintenance à distance par Tailscale, sur un tailnet au compte de l'association
status: accepted
date: 2026-10-30
scope: framing
supersedes: []
superseded-by: []
---

# ADR-0005 — Maintenance à distance par Tailscale, sur un tailnet au compte de l'association

## Context and Problem Statement
[`evo-serv1`](../evo-serv1.md) part au local du club, sur le réseau de l'école, où personne ne peut ouvrir de port entrant. Cet ADR ne couvre que **l'accès des administrateurs** : celui des membres aux services se décide à part ([#19](https://github.com/evolutek/infra/issues/19)). Les administrateurs doivent pouvoir la maintenir depuis chez eux (SSH, déploiements). Personne ne peut se connecter sur sa console : aucun compte n'a de mot de passe. La charte de la salle machines demande l'accord de La Forge pour un accès à distance ; la demande est en cours.

## Considered Options

| Option | Pour | Contre |
|---|---|---|
| Ouvrir le SSH sur Internet (redirection de port) | aucun service tiers | impossible sur le réseau de l'école ; surface exposée à tout Internet |
| WireGuard seul | aucun tiers, aucune limite d'utilisateurs | demande une machine joignable depuis Internet, que le club n'a pas ; clés et règles d'accès à gérer à la main |
| **Tailscale** (WireGuard, coordination hébergée) | connexions uniquement sortantes, passe par des relais sur le port 443 si l'UDP est bloqué ; module NixOS ; gratuit jusqu'à 6 utilisateurs, appareils illimités, usage non commercial | serveur de coordination tiers ; un compte à détenir |
| Headscale (serveur de coordination libre) | aucun tiers, aucune limite d'utilisateurs | il faut une machine joignable depuis Internet pour l'héberger, que le club n'a pas encore |

Compte du tailnet : un compte personnel d'administrateur rendrait le club dépendant d'une personne ; **le compte Google de l'association** se transmet avec elle.

## Decision Outcome
Chosen option: **Tailscale, sur un tailnet ouvert avec le compte Google de l'association**, partagé par les administrateurs, because c'est le seul moyen disponible tout de suite qui ne demande aucune ouverture de port à l'école.

- Le *port mapping* est coupé : aucune demande d'ouverture de port au routeur de l'école.
- Le SSH reste ouvert sur le réseau local en plus de Tailscale : si Tailscale tombe, quelqu'un sur place peut encore se connecter.
- L'expiration de la clé du nœud est désactivée dans la console : la machine ne sort pas du tailnet au bout de 180 jours.
- Configuration : [`modules/services/tailscale.nix`](../../modules/services/tailscale.nix) ; inscription d'une machine : [procédure d'installation](../installer-evo-serv1.md#8-rejoindre-le-tailnet-du-club).

### Consequences
- Good, because une machine au local se maintient comme si elle était sur le réseau de l'administrateur, par son nom (`ssh grand-conseil@evo-serv1`).
- Bad, because un seul compte partagé : tous les administrateurs ont le même accès à la console, on ne sait pas qui s'est connecté, et retirer quelqu'un impose de changer le mot de passe du compte. Les accès SSH restent, eux, nominatifs (une clé par personne dans la configuration).
- Bad, because la coordination dépend de Tailscale ; les connexions restent chiffrées de bout en bout, mais la liste des machines et des connexions lui est connue.
- Good, because le *port mapping* est coupé (`TS_DISABLE_PORTMAPPER`) : Tailscale ne demande pas au routeur d'ouvrir des ports (UPnP, NAT-PMP, PCP), ce qui n'a pas sa place sur le réseau de l'école. Les connexions passent par le perçage de NAT ou les relais.
- Neutral: l'accord de La Forge est demandé en parallèle ; un refus imposerait de couper le service (`enable = false`). Si le club prend un VPS, Headscale pourra remplacer la coordination hébergée ([#19](https://github.com/evolutek/infra/issues/19)).
