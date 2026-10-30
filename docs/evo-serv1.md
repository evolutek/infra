# evo-serv1

Le premier serveur du club : un Lenovo V530-15ICR qui tourne H24 au local. Il sert d'abord à [tester l'agent public](etape-1-agent-public.md), sans NAS ni sauvegarde. Sa configuration est dans [`hosts/evo-serv1/`](../hosts/evo-serv1/) ; sa (ré)installation dans [installer-evo-serv1.md](installer-evo-serv1.md).

**Statut :** NixOS installé le 2026-10-28, [à l'essai](choix-du-systeme.md) ; aucun service encore déployé.

## Matériel

Relevé le 2026-10-28 depuis la session live de NixOS (`lscpu`, `dmidecode`, `lspci`, `smartctl`).

| Élément | Valeur |
|---|---|
| Modèle | Lenovo V530-15ICR, MTM 11BH001FFR, carte IB365MH (Intel B365) |
| Processeur | Intel Core i5-9400, 6 cœurs / 6 threads, 4,1 GHz max, AES-NI, microcode `0xf2` |
| Mémoire | 8 Go DDR4-2666 (un emplacement sur deux), 32 Go max, sans ECC |
| Firmware | BIOS `M2YKT37A`, version définitive ; démarrage UEFI ; TPM 2.0 (Intel PTT) |
| Réseau | Ethernet Realtek RTL8111, 1 Gbit/s ; Wi-Fi Intel AC 3165 (inutilisé) |
| Graphique | Intel UHD 630, intégré |

Lenovo ne développe plus de mise à jour pour ce modèle depuis le 2026-04-30 ([PSREF](https://psref.lenovo.com/syspool/Sys/PDF/Lenovo/Lenovo_V530_15ICR/Lenovo_V530_15ICR_Spec.pdf)). Les failles du firmware qui restent ouvertes sont listées dans la [procédure d'installation](installer-evo-serv1.md#1-mettre-à-jour-le-bios).

## Disques

Pourquoi ce plan : [ADR-0002](decisions/0002-disques-evo-serv1.md). Détail exact : [`disko.nix`](../hosts/evo-serv1/disko.nix).

| Disque | État SMART (2026-10-28) | Rôle | Montage |
|---|---|---|---|
| NVMe Toshiba XG6 256 Go | 12 % d'usure, 9,96 To écrits, 4 621 h | système : EFI 1 Gio + LUKS → btrfs (`/`, `/nix`, `/var`, `/home`) | `/` |
| SSD Crucial m4 256 Go | 11 922 h, 0 secteur réalloué | données vives des services, puis cache local du NAS | `/srv` |
| Disque dur WD Green 1 To, 5 400 tr/min | 45 h, 0 secteur réalloué | sauvegardes locales et archives | `/archive` |

Les trois volumes LUKS se déverrouillent par le TPM ; swap en zram.

## Ce qui tourne dessus

Pendant l'[étape 1](etape-1-agent-public.md) :

| Service | RAM estimée |
|---|---|
| Système et services de base | ~1 Go |
| Agent public (passerelle Discord + cron) | 0,5 à 1 Go |
| OmniRoute, instance dédiée à l'agent | ~0,5 Go |

Total : **2 à 3 Go**. Ces chiffres viennent d'estimations et sont à mesurer une fois les services en place : c'est l'un des buts de l'étape.

Envisagé ensuite, si la machine garde ce rôle : serveurs MCP de l'agent, enregistreur des réunions vocales, transcription ([EvoluBot#16](https://github.com/evolutek/EvoluBot/issues/16)).

## Stockage

- **Le store Nix grossit à chaque génération.** Le ramasse-miettes hebdomadaire (`nix.gc`, générations de plus de 30 jours) et la limite de 10 entrées au menu de démarrage le contiennent.
- **Enregistrements vocaux** : en Opus à 64 kbit/s, une heure fait ~29 Mo ; deux heures de réunion par semaine font ~3 Go par an.
- **Aucune sauvegarde pendant l'étape 1 :** ce qui est dans `/srv` (mémoire et sessions de l'agent, configuration d'OmniRoute) peut être perdu, et c'est accepté ([pourquoi](etape-1-agent-public.md#sans-nas-donc-sans-sauvegarde)). La configuration, elle, est dans ce dépôt. La sauvegarde hors machine arrivera avec le NAS, avant toute donnée réelle.

## Tourner H24

- **Reprise après coupure** : le BIOS est réglé sur *Power On* après une coupure de courant, et le TPM déverrouille les disques sans personne.
- **Consommation** : à mesurer au wattmètre, au repos et en charge.
- **Onduleur** : facultatif, une coupure pendant une mise à jour ne casse pas le système ([ADR-0001](decisions/0001-nixos.md)).
- **À définir** : emplacement au local (ventilation, accès au réseau) et accès à distance pour la maintenance, qui dépend de l'autorisation de la Forge.
