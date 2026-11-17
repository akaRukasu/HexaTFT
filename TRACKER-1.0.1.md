# HEXA 1.0.1 — connexion et actualisation du Tracker

- L’ajout d’un compte vérifie la fiche publique et importe les données avant de fermer le formulaire. Une erreur reste visible dans le formulaire et conserve le compte précédent.
- Le même Riot ID peut être reconnecté immédiatement, sans dépendre du changement d’URL d’une vue ou du prochain passage automatique.
- Le chargement d’une ancienne saison est séparé de celui du compte actuel.
- Le Tracker dispose de boutons visibles pour modifier le compte, actualiser et réessayer. Il précise si une vérification n’a trouvé aucune nouvelle partie publiée.
- Les vérifications au premier plan sont indépendantes des téléchargements PBE et des actualités : retour dans l’application, puis vérification environ chaque minute tant qu’elle reste active. Une requête annulée ne bloque plus la suivante.
- Le lecteur OP.GG accepte les champs référencés, les promesses résolues et les dates sérialisées du transport React. Il conserve la vérification du Riot ID et du serveur avant d’importer des données.
- Les requêtes de compte évitent les cookies partagés et demandent la revalidation du cache. Une réponse de fiche illisible est relue une fois ; les données précédentes restent disponibles en cas d’échec.

La validation inclut une requête réseau native sur le compte public akarukasu#1703 en EUW, l’ajout de ce compte depuis l’interface et une actualisation manuelle. Les cas d’échec, de reconnexion, de conservation du compte précédent et d’annulation sont également couverts.

Les matchs apparaissent au rythme de leur publication par OP.GG. L’actualisation en arrière-plan reste pilotée par iOS ; elle ne constitue pas une connexion permanente.
