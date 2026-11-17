# HEXA 1.0 — analyste personnel et guides de session

Cette livraison met en œuvre le premier socle fonctionnel du cahier des charges du 17 novembre 2026. Elle ajoute un onglet Analyse natif ; les Patches restent accessibles dans Plus.

## Fonctions livrées

- Bilan personnel par set, patch et fenêtre de matchs : moyenne, top 4, places 7–8, distribution et export texte.
- Constats reliés aux matchs : porteurs 1 étoile équipés, or à l’élimination, répartition de l’équipement. Chaque constat sépare faits, hypothèse, exercice et données manquantes.
- Rapport de chaque match, portraits, étoiles, objets complets, composants, recettes et effets lorsqu’ils sont publiés ; note personnelle locale.
- Comparaison des porteurs 1 étoile / 2 étoiles / 3 étoiles ou plus, effectif, petit échantillon et intervalle de Wilson. Un composant ou un objet inconnu ne devient jamais un objet complet.
- Objectif de travail enregistré, référence initiale et suivi des dix premières nouvelles parties du même set. Un rappel préparé apparaît dans Partie.
- Dialogue local sur les résultats, objets, étoiles et dépenses. Les réponses reposent sur des règles explicites, sans abonnement ni clé. Les preuves, le périmètre et la date de chaque réponse sont conservés.
- Passeport des anciens sets et import de leurs parties classées publiques. La requête OP.GG utilise `queueType=RANKED_TFT` ; le Double Up reste séparé. Les relevés détaillés reçus s’accumulent localement. Un résumé de saison et un rang publiés avec des volumes différents restent distincts.
- Les nouvelles parties sont intégrées même si la date de publication du profil est ancienne ; le rang plus récent déjà enregistré reste protégé.
- Guides enrichis à chaque stade : points à vérifier, transitions, conditions de dépense, variantes à étudier et répartition des objets par champion. Les étapes proposées par Hexa restent distinctes des plateaux observés de la source.
- Possibilité de figer le guide et son référentiel pour la session. Les mises à jour des données continuent en dehors du guide figé.
- Mémoire locale protégée, séparation des comptes et possibilité d’effacer objectifs, notes et dialogue.

## Limites explicites

L’historique public décrit les plateaux finaux, pas les boutiques, le banc, les placements ou le timing exact des relances. L’application ne prétend donc pas identifier avec certitude la cause d’une défaite ni garantir une victoire. Le dialogue est un analyste déterministe local ; aucun modèle généraliste distant n’est intégré dans cette livraison. L’analyse vidéo, la reconstruction combat par combat et l’import de VOD du cahier des charges restent à développer.

Les données dépendent de la disponibilité et du rythme de publication des fournisseurs. L’actualisation au premier plan est périodique et un bouton manuel subsiste. L’actualisation en arrière-plan est planifiée par iOS ; elle ne constitue pas une connexion permanente. Les archives nécessitent une connexion pour leur premier import et restent ensuite consultables hors ligne.

## Validation

Les tests natifs incluent 60 matchs anonymisés sur deux sets, les catégories d’équipement, les cohortes, les modes, la conservation des caches existants, les archives, le profil ancien contenant de nouvelles parties et la mémoire locale. Les fixtures sont réservées à la cible de tests et ne préremplissent pas le compte livré.

Les parcours UI couvrent le bilan, les preuves, l’objectif, les cohortes, le dialogue, l’équipement et une note, ainsi que les parcours existants de composition, PBE, tracker, sources, patch et esport. La livraison nécessite la réussite de ces vérifications sur le simulateur macOS et de la compilation Release pour iPhone.
