# Installer evo-serv1

La procédure suivie pour préparer [`evo-serv1`](evo-serv1.md) : BIOS, effacement des disques, installation de NixOS, inscription du TPM. À suivre pour réinstaller cette machine ou préparer la seconde (même modèle).

**Statut :** installé le 2026-10-28, étapes 1 à 8 faites dans cet ordre. Reste à faire : mot de passe administrateur du BIOS, Secure Boot avec lanzaboote.

## 1. Mettre à jour le BIOS

### Pourquoi

La machine est arrivée avec le BIOS `M2YKT17A` (ME 11.8.70.3626). La dernière version publiée est `M2YKT37A`, du 14/07/2023 ; elle est **définitive**, car Lenovo ne supporte plus ce modèle. Elle est installée depuis le 2026-10-28.

De 17A à 37A, le fichier `changes.txt` du paquet liste 12 mises à jour de sécurité :

- avis AMI Aptio SA50075, SA50081, SA50093, SA50150, SA50151, SA50172, SA50174 ;
- FreezeLock NVMe ;
- LEN-115198 ;
- OpenSSL (LEN-115710) ;
- ME annoncé en 11.8.93.4323 (voir ci-dessous : aucun paquet public ne l'installe), microcode `0xF2`.

**Source :** [page de support Lenovo ds541817](https://pcsupport.lenovo.com/downloads/ds541817) et `changes.txt` du paquet.

> **Ce qui reste non corrigé.** Un avis de 2025 sur trois failles des mesures TPM de l'UEFI EDK II ([CVE-2022-36763, -36764, -36765](https://www.cybersecurity-help.cz/vdb/SB2025052193)) donne comme correctif « avant M2YKT38A ». Cette version n'existe pas pour le V530-15ICR : ces trois failles ne seront jamais corrigées sur ce modèle.

> **Le ME reste en 11.8.70.3626.** L'image `IMAGEM2Y.rom` (8 Mo) ne contient que la région BIOS : pas de flash descriptor Intel, aucun manifeste `$MN2`. Le paquet Windows `m2yjy37usa.exe` contient la même image et aucun outil de mise à jour du ME. **Décision : on ne flashe pas de ME de source non officielle.** Le ME est de type « Consumer » : cette plateforme n'a pas d'Intel AMT.

### Préparer la clé, sans Windows

1. Télécharger le paquet « BIOS Update (USB Drive Package) » `m2yjt37usa.zip` depuis la page de support et vérifier son empreinte :
   - SHA-256 `c8788978afea042f0242de8830fac4ae11bb0fcc6b8f300ff8bbdcb00ea02914` ;
   - taille 6 853 683 octets.
2. Formater une clé en FAT32, sur une partition GPT marquée `esp`.
3. Copier le contenu du zip à la racine de la clé.

La clé contient un shell UEFI (`efi/boot/BOOTX64.efi`) qui exécute `startup.nsh`, lequel lance `flash2.efi IMAGEM2Y.rom /bb /rsmb /bgd`. L'option `/rsmb` conserve les tables SMBIOS (numéro de série, modèle, UUID).

### Flasher

1. Dans le BIOS (F1) : **Secure Boot désactivé** et **CSM désactivé**, comme l'exige le readme de Lenovo.
2. Démarrer avec F12 et choisir l'entrée **UEFI** de la clé.
3. Le flash dure environ 2 minutes. **Ne pas couper le courant.**
4. `flash2.efi` demande s'il faut mettre à jour le numéro de série et le type de machine : **répondre N à chaque question**. S'il était effacé, `flash2.efi /sn:<numéro>` le rétablit.
5. Retirer la clé au redémarrage, puis vérifier dans F1 la version `M2YKT37A`.

## 2. Régler le BIOS (F1)

| Réglage | Valeur |
|---|---|
| Horloge | UTC |
| SATA | AHCI |
| VT-x, VT-d | activés (conteneurs et machines virtuelles) |
| After Power Loss | Power On : la machine redémarre seule après une coupure |
| ErP | désactivé (sinon Wake on LAN ne marche pas machine éteinte) |
| Wake on LAN | activé |
| Secure Boot | désactivé pour l'installation, réactivable plus tard avec [lanzaboote](https://github.com/nix-community/lanzaboote) |
| CSM | désactivé : démarrage UEFI pur |

- Le setup n'affiche pas d'option « Security Chip », mais le TPM 2.0 (Intel PTT) est actif : Linux le voit en `/sys/class/tpm/tpm0`.
- Mot de passe administrateur du BIOS : reporté. Il ira dans le gestionnaire de mots de passe du club.

## 3. Préparer la clé NixOS

1. Télécharger l'ISO minimale NixOS 26.05 (`nixos-minimal-26.05.12707.718f670e8453-x86_64-linux.iso`) et son fichier `.sha256` officiel, puis vérifier la somme.
2. L'écrire sur le **périphérique entier** de la clé (pas une partition) avec `dd … bs=4M oflag=sync`.

Cette ISO est construite sur le même commit de nixpkgs que [`flake.lock`](../flake.lock) : l'installation retélécharge peu de paquets.

## 4. Se connecter et relever le matériel

1. Brancher la machine en Ethernet et démarrer sur la clé NixOS (F12, entrée UEFI).
2. `sudo loadkeys fr` si le clavier est en AZERTY, puis `passwd` pour un mot de passe temporaire.
3. Se connecter en SSH depuis un portable du même réseau (`ssh nixos@<adresse>`, adresse donnée par `ip -br addr`).
4. Relever le matériel **en lecture seule** : `lscpu`, `dmidecode`, `lspci`, `lsblk`, `smartctl`, présence du TPM. Le résultat du 2026-10-28 est dans la [fiche de la machine](evo-serv1.md#matériel).

Ne rien partitionner avant ce relevé. Ne pas publier les numéros de série qu'il affiche.

## 5. Effacer les disques

Les disques venaient de machines d'occasion et portaient des données de tiers : ils sont effacés entièrement avant l'installation.

### Dégeler les disques

Le BIOS Lenovo « gèle » (*frozen*) les disques SATA au démarrage : l'ATA Secure Erase est alors refusé. Une veille S3 réveillée par l'horloge les dégèle, sans toucher à la machine :

```sh
sudo rtcwake -m mem -s 25
```

Au réveil, `hdparm -I /dev/sdX` montre `not frozen`.

### NVMe : retour usine Opal

Le NVMe Toshiba est un disque autochiffrant (SED) TCG Opal 2 (`MediaEncrypt = Y`). Il refuse `nvme sanitize` et `nvme format --ses` (« Access Denied », `0x4286`), même après la veille. Avec [sedutil](https://github.com/Drive-Trust-Alliance/sedutil) :

```sh
sudo sedutil-cli --initialSetup <mot de passe temporaire> /dev/nvme0n1
sudo sedutil-cli --revertTPer <le même mot de passe> /dev/nvme0n1
```

Le disque régénère sa clé de chiffrement (effacement cryptographique) et revient à l'état d'usine, sans mot de passe. Vérifier que la signature GPT a disparu (`dd … skip=1 count=1` ne doit plus montrer `EFI PART`). En dernier recours, le PSID imprimé sur l'étiquette du disque permet toujours un retour usine.

### SSD et disque dur SATA : ATA Secure Erase

```sh
sudo hdparm --user-master u --security-set-pass <mot de passe temporaire> /dev/sdX
sudo hdparm --user-master u --security-erase-enhanced <le même mot de passe> /dev/sdX
```

Le disque retire le mot de passe à la fin. Pendant l'effacement, ne pas interroger le disque (`hdparm -I` reste bloqué) : lancer la commande dans une unité systemd (`systemd-run`) pour qu'elle survive à une coupure SSH.

| Disque | Durée | Résultat (2026-10-28) |
|---|---|---|
| SSD Crucial m4 | 21 s | ne relit que des zéros (début, milieu, fin) |
| Disque dur WD Green | 145 min (150 annoncées) | ne relit que des zéros (début, milieu, fin) |

## 6. Installer NixOS

Depuis la session live, avec une copie de ce dépôt dans `~/infra`. Les commandes longues tournent dans une unité systemd (`systemd-run`) pour survivre à une coupure SSH ; il faut alors lui passer le `PATH` du système, sinon `nixos-install` ne trouve pas ses outils.

1. Générer une clé LUKS temporaire aléatoire. Elle ne sort pas de la machine et disparaît avec la RAM de la session live :
   ```sh
   (umask 077; head -c 48 /dev/urandom | base64 -w0 > /tmp/luks-install.key)
   ```
2. Partitionner, chiffrer et monter les trois disques d'après [`disko.nix`](../hosts/evo-serv1/disko.nix) (1 min 40 le 2026-10-28) :
   ```sh
   sudo nix --experimental-features 'nix-command flakes' run github:nix-community/disko -- \
     --mode destroy,format,mount --yes-wipe-all-disks --flake ~/infra#evo-serv1
   ```
3. Installer (2 min : nixpkgs est figé sur le commit de l'ISO, presque tout est déjà en cache) :
   ```sh
   sudo nixos-install --flake ~/infra#evo-serv1 --no-root-passwd --no-channel-copy
   ```

## 7. Inscrire le TPM et la clé de secours

**Avant de redémarrer**, toujours depuis la session live. Secure Boot désactivé, le PCR 7 a la même valeur sous la live et sous le système installé : une clé scellée maintenant ouvrira les disques dès le premier démarrage. Pour chacun des trois volumes (`/dev/disk/by-partlabel/disk-system-system`, `disk-data-data`, `disk-archive-archive`) :

1. Sceller une clé dans le TPM :
   ```sh
   sudo systemd-cryptenroll --unlock-key-file=/tmp/luks-install.key --tpm2-device=auto --tpm2-pcrs=7 <volume>
   ```
2. Créer une clé de secours, **dans son propre terminal** (elle s'affiche à l'écran) :
   ```sh
   sudo systemd-cryptenroll --unlock-key-file=/tmp/luks-install.key --recovery-key <volume>
   ```
   Elle est la seule issue si le TPM refuse un jour d'ouvrir le disque : la ranger aussitôt hors de la machine (une note sécurisée par machine, un champ masqué par disque), avec une copie papier. Vérifier avec `sudo systemd-cryptenroll <volume>` que les slots `password`, `tpm2` et `recovery` existent.
3. Démonter et redémarrer, en retirant la clé USB :
   ```sh
   sudo umount -R /mnt && sudo reboot
   ```
   La machine démarre jusqu'à l'invite `evo-serv1 login:` sans rien demander : le TPM a ouvert les disques. Personne ne peut se connecter sur la console (aucun compte n'a de mot de passe) : l'accès se fait par SSH, avec un compte et une clé déclarés dans [`configuration.nix`](../hosts/evo-serv1/configuration.nix).
4. Le système installé a sa propre clé d'hôte SSH : au premier `ssh`, l'alerte « REMOTE HOST IDENTIFICATION HAS CHANGED » est normale si l'empreinte enregistrée est celle de la session live. Retirer l'ancienne ligne (`ssh-keygen -R <adresse>`) et reconnecter.
5. Le démarrage par le TPM étant vérifié, vider le slot de la clé temporaire, désormais perdue :
   ```sh
   sudo systemd-cryptenroll --unlock-tpm2-device=auto --wipe-slot=password <volume>
   ```
   Il reste deux slots par volume : `tpm2` et `recovery`.
6. Retirer l'entrée UEFI de l'ancien Windows, qui pointe vers un disque effacé (`efibootmgr` n'est pas installé : `nix build --print-out-paths nixpkgs#efibootmgr`) :
   ```sh
   sudo efibootmgr -b <numéro de l'entrée « Windows Boot Manager »> -B
   ```

Vérifié le 2026-10-28 : les trois volumes s'ouvrent seuls, sept montages en place, swap zram de 3,8 Go, aucune unité en échec.

## 8. Rejoindre le tailnet du club

Pour la maintenance à distance ([ADR-0005](decisions/0005-acces-distance-tailscale.md)). Le service est déjà dans la configuration ; il reste à inscrire la machine, une seule fois :

1. Sur la machine :
   ```sh
   sudo tailscale up --hostname=evo-serv1
   ```
   La commande affiche un lien de connexion à usage unique.
2. Ouvrir ce lien, connecté avec le compte Google de l'association. La machine apparaît dans la console Tailscale.
3. Dans la console, sur la machine : **⋯ → Disable key expiry**. Sans ça, elle sort du tailnet au bout de 180 jours.
4. Depuis un poste du tailnet : `ssh grand-conseil@evo-serv1` doit répondre.

L'inscription est gardée dans `/var/lib/tailscale` : elle survit aux redémarrages et aux `switch`, pas à une réinstallation. Après une réinstallation, retirer l'ancienne machine de la console avant de refaire ces étapes.
