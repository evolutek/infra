# Schémas de l'architecture

Pour discuter de la même chose : quelles machines, quels services, quelles dépendances externes, et comment on y accède. **Rien n'est décidé** : ce qui est en pointillés reste à trancher, et les phases n'ont pas d'ordre imposé.

Chaque schéma existe en image et en fichier `.excalidraw`, à ouvrir sur [excalidraw.com](https://excalidraw.com) pour le modifier.

## Deux architectures à comparer

**Un rôle par machine** : l'agent reste seul sur sa machine, l'IoT, les données et les services de l'association vivent ailleurs.

![Vision cible](01-vision-cible.png)

**Une seule machine sous TrueNAS** : la proposition faite dans la discussion sur la PR #1, à faire valider par son auteur.

![Option TrueNAS](02-option-truenas.png)

## Les phases

**Phase 1 : `evo-serv1` seul.** EvoluBot, OmniRoute, et le gestionnaire de mots de passe en attendant sa vraie place.

![Phase 1](03-phase-1-evo-serv1.png)

**Phase 2 : une machine dédiée à l'IoT du local.** Home Assistant reste à confirmer.

![Phase 2](04-phase-2-iot.png)

**Phase 3 : le NAS.** TrueNAS ou autre, à choisir ; il reçoit les données et les sauvegardes.

![Phase 3](05-phase-3-nas.png)

**Phase 4 : `evo-serv2`.** Seulement si le NAS ne suffit pas à porter les services de l'association.

![Phase 4](06-phase-4-evo-serv2.png)
