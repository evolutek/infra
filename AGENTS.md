# Règles du dépôt

Pour toute personne ou tout agent qui modifie ce dépôt.

## Documentation

- **Tout ce qui concerne ce dépôt est documenté ici**, dans `docs/` : fiches des machines, procédures, sécurité, décisions. Le vault du club ne fait que renvoyer à ce dépôt ; on n'y recopie rien.
- Une page par question du lecteur. Un fait vit à un seul endroit ; ailleurs, on met un lien.
- Docs en français. Code, commentaires et messages de commit en anglais.
- Commentaires rares : seulement le *pourquoi* quand il n'est pas évident.
- Une décision structurante (système, disques, topologie, choix d'un service) est un ADR dans `docs/decisions/`, avec les options écartées et pourquoi. On ne modifie pas un ADR accepté : un nouvel ADR le remplace.

## Dépôt public

N'écrivez jamais dans ce dépôt : un secret (jeton, mot de passe, clé privée), un numéro de série, une adresse IP, un nom de personne. Les disques sont désignés par `/dev/disk/by-path/…` (port de la carte mère) et jamais par `by-id`, qui contient le numéro de série.

## Avant chaque PR

- La configuration de chaque machine touchée s'évalue :
  `nix eval --raw .#nixosConfigurations.<machine>.config.system.build.toplevel.drvPath`
- `flake.lock` n'est mis à jour (`nix flake update`) que dans une PR dédiée.
- Messages de commit au format [Conventional Commits](https://www.conventionalcommits.org/), sans signature d'outil.
- La branche `main` est protégée : PR obligatoire, deux approbations, merge en *rebase* uniquement, pour que chaque commit reste dans l'historique. Chaque commit doit donc avoir un sens propre : on nettoie l'historique de sa branche avant la relecture.
