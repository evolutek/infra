# Sécurité de l'hôte

Comment les serveurs du club se protègent, et ce que ça exige de leur système. Les attaques visées viennent surtout de l'agent du club : il lit du contenu écrit par des inconnus et peut être détourné par *prompt injection*. Ce modèle de menace et les droits de l'agent sur chaque plateforme sont décrits dans [EvoluBot](https://github.com/evolutek/EvoluBot) (`docs/securite-agent.md`, `docs/spec-agent-hermes.md`). Le choix du système applique les critères ci-dessous dans l'[ADR-0001](decisions/0001-nixos.md).

## Le conteneur ne suffit pas seul

Un conteneur n'est pas une machine virtuelle : il partage le noyau de l'hôte. Ce qui empêche un service de sortir de son conteneur pour accéder au reste de la machine, c'est le noyau et le runtime de conteneurs (runc, crun, Podman), donc des paquets de l'hôte. Les évasions de conteneur exploitent justement des failles de ces composants, par exemple [runc CVE-2024-21626](https://github.com/opencontainers/runc/security/advisories/GHSA-xr7r-f8xq-vfvv) (sévérité haute).

Mettre un service en conteneur ne rend donc pas les mises à jour de l'hôte inutiles : il en fait la dernière barrière. Une veille des failles qui touchent la machine prévient quand une mise à jour ne peut pas attendre ([EvoluBot#24](https://github.com/evolutek/EvoluBot/issues/24)).

## Règles des conteneurs

- **Utilisateur non root** dans le conteneur.
- **Runtime rootless** (Podman rootless ou user namespaces) : un « root » dans le conteneur n'est qu'un utilisateur sans droits sur l'hôte, ce qui limite les dégâts d'une évasion.
- **Jamais de socket Docker monté** : y accéder revient à être root sur l'hôte.
- **Capabilities retirées** (`--cap-drop=ALL`) et `no-new-privileges`.
- **Système de fichiers en lecture seule**, sauf les volumes de données du service.
- **Images à jour** : les bibliothèques des images ont leurs propres failles ; elles se reconstruisent régulièrement, indépendamment des mises à jour de l'hôte.

## Règles des services natifs

Un service lancé directement par systemd, sans conteneur (comme Hermes, [ADR-0003](decisions/0003-hermes-service-natif.md)), suit les mêmes règles, traduites en options de son unité :

| Règle des conteneurs | Option systemd |
|---|---|
| Utilisateur non root | utilisateur système dédié, sans mot de passe ni clé SSH |
| Capabilities retirées, `no-new-privileges` | `CapabilityBoundingSet=` vide, `NoNewPrivileges=true`, `RestrictSUIDSGID=true` |
| Système de fichiers en lecture seule | `ProtectSystem=strict` et `ReadWritePaths=` limité à ses données ; `ProtectHome=true` |
| Pas d'accès au noyau | `ProtectKernel*`, `ProtectControlGroups`, `PrivateDevices`, `SystemCallFilter=@system-service` |
| Ressources bornées | `MemoryMax=` |

`systemd-analyze security <unité>` note le résultat. Un processus que le service lance hors de son unité (par `systemd-run`) n'hérite pas de ces options : il faut le savoir et le limiter autrement.

## Critères pour choisir le système

Sur un hôte qui fait surtout tourner des conteneurs, le système compte par la façon dont il applique ses correctifs.

| Critère | Pourquoi |
|---|---|
| **Correctifs automatiques, noyau compris** | Le noyau et le runtime sont la barrière du conteneur ; un correctif qui attend une intervention humaine laisse la faille ouverte. |
| **Redémarrage sûr** | Un correctif du noyau n'agit qu'après redémarrage. Si un redémarrage raté laisse la machine éteinte dans le local, on finit par reporter les mises à jour : il faut pouvoir revenir seul à la version précédente. |
| **Surface minimale** | Chaque service ou paquet installé sur l'hôte est une faille possible de plus. |
| **Runtime rootless disponible** | Sans lui, une évasion du conteneur donne root sur l'hôte. |
| **Configuration de l'hôte relisible** | Pare-feu, SSH et services se relisent et se valident par PR ; une modification faite à la main sur la machine ne passe pas inaperçue. |

## Accès et chiffrement

- **SSH par clé uniquement** : ni mot de passe, ni connexion root. Les comptes n'existent que par la configuration (`users.mutableUsers = false`).
- **Aucun port ouvert vers Internet** : la maintenance à distance passe par le tailnet du club, en connexions sortantes, sans demande d'ouverture de port au routeur ([ADR-0005](decisions/0005-acces-distance-tailscale.md), [schéma](schemas/acces-distants.png)).
- **Disques chiffrés** par LUKS, déverrouillés par le TPM, avec une clé de secours hors machine : [ADR-0002](decisions/0002-disques-evo-serv1.md).
- **Séparation des dépôts** : l'agent du club propose ses changements par PR sur EvoluBot, jamais sur ce dépôt. Un agent détourné ne peut donc pas modifier la configuration de la machine qui le fait tourner.
