# Administrer OmniRoute

OmniRoute relaie les requêtes de l'agent du club vers les fournisseurs de modèles. Il tourne sur [`evo-serv1`](evo-serv1.md) dans un conteneur Podman rootless, sous l'utilisateur `omniroute` ; pourquoi ce choix : [ADR-0006](decisions/0006-omniroute-podman-rootless.md). Configuration : [`modules/services/omniroute.nix`](../modules/services/omniroute.nix).

Quels fournisseurs l'agent a le droit d'utiliser, et pour quelles données, se décide dans [EvoluBot](https://github.com/evolutek/EvoluBot) ([#29](https://github.com/evolutek/EvoluBot/issues/29)), pas ici.

## Ouvrir le tableau de bord

Il n'écoute que sur la machine (`127.0.0.1:20128`). Depuis un poste d'administrateur :

```sh
ssh -i ~/.ssh/<sa clé> -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes -L 20128:127.0.0.1:20128 grand-conseil@evo-serv1
```

puis `http://localhost:20128` dans le navigateur. `-N` ouvre le tunnel sans shell (on le ferme par `Ctrl+C`) ; `ServerAliveInterval` l'empêche d'être coupé en silence par une box ; `ExitOnForwardFailure` fait échouer la commande si le port local est déjà pris. Si la page ne répond plus, c'est presque toujours le tunnel qui s'est fermé : le relancer.

Le mot de passe est `INITIAL_PASSWORD`, dans les secrets ; à lire dans son propre terminal, depuis le clone de ce dépôt, avec `SOPS_AGE_SSH_PRIVATE_KEY_FILE` réglé ([secrets.md](secrets.md)) :

```sh
sops -d --extract '["omniroute"]["env"]' secrets/evo-serv1.yaml | grep INITIAL_PASSWORD
```

Il n'a pas à être recopié ailleurs (navigateur…) : le dépôt chiffré est sa seule source.

Ne pas le changer depuis le tableau de bord : `INITIAL_PASSWORD` n'agit que tant qu'aucun mot de passe n'est enregistré, et le dépôt ne connaîtrait plus le bon.

## Ce qui reste dans le tableau de bord

Les connexions aux fournisseurs (clés, comptes OAuth) et les clés d'API données aux clients se créent dans l'interface ou par l'API (plus bas) et vivent dans la base, sous `/srv/omniroute`. Leurs valeurs y sont chiffrées champ par champ par `STORAGE_ENCRYPTION_KEY` ; perdre ce secret, c'est perdre ces identifiants. La base n'est pas décrite par ce dépôt : elle se sauvegarde ([#3](https://github.com/evolutek/infra/issues/3)).

## Connexions aux fournisseurs

Chaque connexion se règle à sa création (*Providers*, puis le fournisseur) ; les valeurs propres à chaque fournisseur sont dans [EvoluBot](https://github.com/evolutek/EvoluBot), page `docs/llm/comptes.md`. Deux réglages dépendent de la façon dont le fournisseur compte ses quotas :

- **Per-Model Quota** : activé quand les limites sont par modèle (Groq), pour qu'un 429 ne bloque que ce modèle ; désactivé quand le quota est commun à tous les modèles (Cloudflare), pour que la connexion entière s'arrête quand il est épuisé. Sans lui, une erreur répétée sur un seul modèle met toute la connexion en pause : on exclut alors (*Excluded Models*, liste séparée par des virgules, joker `*` accepté) les modèles qui échouent à coup sûr. L'option est enregistrée sous le nom `passthroughModels`.
- **Protection de débit** : le badge bouclier *Unprotected* sur la ligne de la connexion ; un clic le passe à *Protected*. OmniRoute met alors les requêtes en file pour respecter les limites connues, au lieu d'encaisser des 429 qui consomment le quota. À activer sur chaque connexion.

Un fournisseur absent de la liste, ou dont la carte vise la mauvaise adresse, passe par un **nœud OpenAI-compatible** : *Providers → Add OpenAI Compatible* (nom, préfixe qui deviendra `<préfixe>/<modèle>` pour les clients, *Base URL* jusqu'à la version, sans `/chat/completions`), puis *Add Connection* sur ce nœud, qui porte la clé. Le préfixe ne doit pas reprendre celui d'un fournisseur intégré. *Sync* sur la connexion importe le catalogue du fournisseur ; un modèle qu'il ne liste pas s'ajoute à la main sur le nœud.

## Suivre les quotas sans le tableau de bord

Un **jeton d'accès** (*Settings → Access Tokens*, `oma_live_…`) en portée `read` lit l'administration sans pouvoir appeler un modèle ni changer un réglage. On le garde dans un trousseau (par exemple `secret-tool` sur GNOME), et on l'envoie par l'entrée standard pour qu'il n'apparaisse ni dans l'historique ni dans la liste des processus :

```sh
secret-tool lookup service omniroute host evo-serv1 user <nom du jeton> \
  | sed 's/^/Authorization: Bearer /' \
  | ssh grand-conseil@evo-serv1 "curl -sS -H @- http://127.0.0.1:20128/api/rate-limits"
```

`/api/rate-limits` donne l'état de chaque connexion (protection, verrouillages après 429) ; `/api/usage/<connexion>` la consommation ; `/api/usage/model-latency-stats` la latence et le taux de succès par modèle ; `/api/resilience/model-cooldowns` les modèles en pause et pourquoi.

## Administrer par l'API

Tout ce que fait le tableau de bord passe aussi par l'API, avec un jeton d'accès envoyé de la même façon. La portée décide de ce qu'il peut faire :

| Portée | Permet | Ne permet pas |
|---|---|---|
| `read` | lire l'état, les quotas, les clés (sans leur valeur) | toute modification |
| `write` | les écritures qui ne sont pas réservées à `admin` | modifier une connexion (refusé : `AUTH_SCOPE`) |
| `admin` | tout, y compris créer des jetons | — |

Un jeton `admin` ne se crée que depuis le tableau de bord ; on lui donne une expiration d'un jour et on le révoque après usage. `GET /api/cli/whoami` dit quel jeton est utilisé, avec sa portée et son expiration.

| Action | Route |
|---|---|
| Créer une connexion | `POST /api/providers` : `provider`, `name`, `apiKey`, `providerSpecificData` ; elle naît inactive |
| La tester, puis l'activer | `POST /api/providers/<id>/test`, puis `PATCH /api/providers/<id>` avec `isActive` |
| Modifier ses réglages | `PATCH /api/providers/<id>` ; `providerSpecificData` est remplacé en entier, on renvoie donc tous ses champs |
| Protection de débit | `POST /api/rate-limits` avec `connectionId` et `enabled` (le `PATCH` ignore ce champ sans erreur) |
| Ajouter un modèle à un nœud | `POST /api/provider-models` avec `provider`, `modelId`, `isFree` ; `validate-and-add` fait d'abord trois appels réels et refuse un modèle qui met plus de 20 s à répondre |
| Créer une clé pour un client | `POST /api/keys` avec `name` et `scopes: []` ; sa valeur n'est rendue qu'une fois |
| Restreindre une clé | `PATCH /api/keys/<id>` avec `allowedConnections` (identifiants des connexions), `allowAutoCombos`, `noLog` |
| Révoquer un jeton | `DELETE /api/cli/tokens/<id>` |

La synchronisation du catalogue (*Sync*) exige une session du tableau de bord, même avec un jeton `admin`.

Deux règles, parce que l'API répond « succès » même quand un champ n'est pas pris en compte : **relire après chaque écriture**, et faire passer toute clé de fournisseur dans le corps envoyé sur l'entrée standard, jamais dans un argument de commande.

## Mettre à jour l'image

Une version se choisit par PR, en changeant la version **et** le digest de `image` dans le module. Le digest d'une version :

```sh
curl -s https://hub.docker.com/v2/repositories/diegosouzapw/omniroute/tags/<version> | jq -r .digest
```

Avant de passer à une version, lire ses notes et les [avis de sécurité](https://github.com/diegosouzapw/OmniRoute/security/advisories) de l'amont. Après le déploiement : `systemctl status podman-omniroute` et `journalctl -u podman-omniroute`.

## Commandes utiles

Le conteneur appartient à `omniroute`, pas à root : `podman` se lance sous ce compte.

```sh
cd / && sudo -u omniroute XDG_RUNTIME_DIR=/run/user/970 podman ps
cd / && sudo -u omniroute XDG_RUNTIME_DIR=/run/user/970 podman stats --no-stream
```
