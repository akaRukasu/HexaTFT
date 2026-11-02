# Hexa — compagnon TFT pour iPhone

Version 0.1.0, créée le 3 novembre 2026. Usage : TFT sur PC, iPhone à côté.

**Il s’agit d’un premier prototype natif, pas d’une application complète connectée à la méta.** Le projet Xcode et les sources sont fournis. Aucune compilation iOS ni exécution sur iPhone n’a pu être faite dans l’environnement Linux de création. Les vérifications locales couvrent les fichiers de données, la structure du projet et les interactions JavaScript de l’aperçu (sans rendu navigateur) ; les tests XCTest fournis restent à lancer sur macOS.

## Ce qui est implémenté

- Interface SwiftUI en français, sombre, pour iOS 17 et versions suivantes.
- Recherche de guides, favoris, fiches, principes de placement et d’objets.
- Épinglage d’un guide et consultation manuelle de six étapes (2-1 à 6-1).
- Maintien optionnel de l’écran allumé uniquement quand l’onglet Partie est visible et l’application active.
- Constructeur de plateau 4 × 7 : ajout, remplacement, retrait, sauvegarde et partage textuel.
- Codex français : champions, objets, traits et optimisations issus de Riot Data Dragon 16.21.1, snapshot téléchargé le 3 novembre 2026. Les textes sont embarqués ; les images sont chargées en ligne et remplacées par des initiales hors connexion.
- Filtres de sets : les données regroupent plusieurs sets et ne déterminent pas le set actuellement joué.
- Journal local de résultats, notes et calcul du top 4 sur les parties saisies.
- Import local de catalogues JSON, validation avant remplacement et conservation du dernier catalogue valide.
- Sauvegardes atomiques dans Application Support. Aucune clé API ni compte Riot dans l’application.

## Ce qui reste à développer

- Vraies compositions de méta : source autorisée, fraîcheur du patch et couverture statistique à établir.
- Compositions avec unités, équipements et positions prescrits dans chaque phase ; les guides inclus expliquent seulement des archétypes économiques.
- Recettes d’objets, associations complètes des traits et statistiques détaillées : Data Dragon ne fournit pas tout dans les fichiers utilisés ici.
- Actualisation automatique des données et gestion des changements de set.
- Compte Riot, historique automatique et bilan après partie via un serveur conservant les secrets.
- Évaluation de l’accessibilité et de l’ergonomie sur un appareil réel.
- Icône définitive, signature, TestFlight ou autre distribution, et validation des usages par Riot.

## Tester sur Mac

1. Ouvrir `HexaTFT.xcodeproj` dans Xcode 16 ou ultérieur.
2. Choisir le schéma `HexaTFT` et un simulateur iPhone avec iOS 17 ou ultérieur.
3. Exécuter avec ⌘R. Lancer les tests avec ⌘U.
4. Pour un vrai iPhone, choisir une équipe dans Signing & Capabilities et remplacer `com.example.HexaTFT` par un identifiant unique. La signature Apple est nécessaire.

La génération du projet ne nécessite pas XcodeGen ni de package tiers. `python3 scripts/prepare_project.py` régénère le fichier Xcode si besoin.

## Compiler depuis Windows avec GitHub Actions

Le dépôt n’a pas été créé ni envoyé sur GitHub. Après avoir ajouté le contenu de ce dossier à la racine d’un dépôt, le workflow `.github/workflows/ios.yml` peut être lancé dans Actions → Build and test iOS → Run workflow. Il choisit un simulateur disponible, exécute les tests, puis produit `HexaTFT-unsigned.ipa`.

**Ce workflow est fourni mais n’a pas été exécuté. L’IPA obtenue est non signée et ne s’installe pas directement.** Il faut la signer par une méthode de développement ou de distribution adaptée. TestFlight nécessite un compte Apple Developer et une configuration de signature ; aucun certificat ni abonnement n’est inclus.

## Données et catalogues

Les trois guides inclus sont signalés « pédagogiques » : Reroll à 1 PO, Reroll à 2 PO et Fast 8. Ils ne revendiquent aucun rang de méta, taux de victoire ni adaptation au patch actuel. Les niveaux et paliers économiques sont des repères généraux, pas des instructions personnalisées.

Le bouton d’import de Plans accepte un fichier `.json`. Le fichier `HexaTFT/Resources/catalogue.json` sert d’exemple complet du format : `schemaVersion`, `patch`, `updatedAt`, `source`, `isDemo` et `guides`. Chaque guide possède un identifiant unique et exactement une phase pour chacune des étapes `2-1`, `2-5`, `3-2`, `4-1`, `5-1`, `6-1`. Limites : 2 Mo et 200 guides. `isDemo=false` indique seulement une déclaration du fournisseur ; l’application ne vérifie pas indépendamment la qualité de la source.

Les données officielles proviennent de :

- https://ddragon.leagueoflegends.com/api/versions.json
- https://ddragon.leagueoflegends.com/cdn/16.21.1/data/fr_FR/tft-champion.json
- https://ddragon.leagueoflegends.com/cdn/16.21.1/data/fr_FR/tft-item.json
- https://ddragon.leagueoflegends.com/cdn/16.21.1/data/fr_FR/tft-trait.json
- https://ddragon.leagueoflegends.com/cdn/16.21.1/data/fr_FR/tft-augments.json

Les descriptions peuvent conserver des paramètres bruts entre @…@ ou accolades : aucune valeur manquante n’est inventée. Les éléments non attribuables à un set sont regroupés sous « Commun ». Le Codex n’expose pas de taux de victoire d’optimisations.

## Portée du mode Partie

La sélection d’une étape ouvre une page statique d’un guide préparé avant la partie. Le plateau personnel ne recalcule aucune recommandation. Le projet n’observe pas le PC, ne suit pas les adversaires et ne prend aucune décision à la place du joueur.

La politique TFT distingue ces guides des recommandations dynamiques basées sur l’état courant de la partie. Une intégration PC éventuelle et ses usages devront être évalués séparément ; l’existence d’un accès technique n’implique pas son autorisation : https://developer.riotgames.com/docs/tft

Riot demande l’enregistrement des produits destinés aux joueurs. L’enregistrement et toute demande d’accès de production ne sont pas réalisés ici.

## Vérifications

`python3 scripts/check_content.py` vérifie les données et toutes les références du projet Xcode. Les tests natifs fournis vérifient les catalogues invalides, le remplacement transactionnel et la persistance des résultats, du plan épinglé et de l’étape sélectionnée. Leur exécution exige Xcode.

`apercu.html` est une maquette interactive locale de présentation, pas le rendu d’un simulateur iOS. Les boutons Plans et Partie y permettent de parcourir les guides embarqués. Elle n’installe pas l’application.

Projet indépendant, non affilié à Riot Games. Les noms, contenus et marques TFT appartiennent à leurs ayants droit.
