# Vérification de la version 0.1

Effectuée le 3 novembre 2026 dans un environnement Linux.

- Vérification portable du contenu : réussie.
- Catalogue : 3 guides, 6 phases distinctes par guide, identifiants uniques.
- Codex : 2 571 entrées nommées, identifiants uniques, images sur le domaine officiel Data Dragon. Les 13 éléments sans nom affichable ont été exclus.
- Projet Xcode : graphe de 43 objets cohérent, chemins des sources et ressources présents, schéma partagé valide.
- Aperçu : syntaxe JavaScript et interactions vérifiées dans un petit environnement DOM de contrôle (chargement, changement d’étape, navigation, choix de guide).
- Compilation Swift, XCTest natifs, simulateur et iPhone : non exécutés, Xcode indisponible.
- Rendu navigateur : non vérifié ; le téléchargement du navigateur de test n’a pas abouti.
- Workflow GitHub Actions : fourni, non exécuté.

Les tests structurels ne garantissent pas que le projet compile. Le premier passage sur macOS doit inclure une compilation, les XCTest et une vérification visuelle sur iPhone avant toute diffusion.
