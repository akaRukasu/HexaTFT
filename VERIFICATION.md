# Vérification de la version 0.1

Effectuée le 3 novembre 2026.

- Vérification portable des données et du projet : réussie.
- Catalogue : trois guides pédagogiques et six étapes chacun.
- Codex : 2 571 entrées nommées, identifiants uniques.
- Compilation Xcode pour simulateur : réussie.
- Deux tests XCTest (validation des catalogues et persistance/import transactionnel) : réussis.
- Compilation Release iPhone ARM64 : réussie.
- Production et publication de l’artefact GitHub Actions : réussies.
- IPA récupérée : archive intègre, exécutable Mach-O 64 bits ARM64, version 0.1.0, minimum iOS 17.0, ressources reference.json et catalogue.json présentes.
- Signature Apple : absente, intentionnellement.
- Vérification manuelle sur iPhone et rendu visuel du simulateur : non réalisés.

Workflow : https://github.com/akaRukasu/HexaTFT/actions/runs/41544918319

Commit source de l’IPA : 130921a07612b3c496243345deee73ddb753ccde

L’application reste un prototype avec guides pédagogiques, sans compos méta actualisées ni synchronisation avec la partie PC.
