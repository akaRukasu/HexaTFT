# HexaTFT Ultimate 0.4

## Audit et périmètre

La version 0.3 mélangeait un seul catalogue de compositions et un seul Codex avec un cache global. Ultimate isole les versions de production, les révisions expérimentales et les archives. Les guides interactifs, favoris, plateaux personnels, recettes et notes existants sont conservés. La copie vers l’atelier utilise le Codex compatible avec ses données historiques.

Le dépôt livre un Codex EUW vérifié par la version des ressources Riot, le Codex PBE de CommunityDragon, un comparateur, les notes éditoriales Riot, le calendrier et les actualités esport, un tracker iOS et un serveur Riot privé. Le catalogue Blitz du 3 novembre reste accessible dans Archives. Les nouvelles données natives de composition proviennent d’un flux HTTPS autorisé. Les pages d’origine restent consultables dans l’annuaire. Les PBE historiques de Mobalytics sont des synthèses Hexa datées avec des liens. Les guides du nouveau build apparaissent lorsque le flux autorisé en fournit. L’atelier de synergies lit directement les unités et paliers du build PBE.

## Audit des sources

| Source | Usage dans Ultimate | Vérification et limites |
|---|---|---|
| Riot Games | Profil et matchs via la passerelle, version des ressources EUW, publications et calendrier | Les API de compte, de classement et de matchs nécessitent un accès approuvé. Le calendrier annonce des dates. |
| CommunityDragon | Codex LIVE/PBE, paliers et comparateur | Export de fichiers du client, provenance communautaire. Aucun résultat de partie. |
| Blitz | Archive déjà embarquée et lien vers la méta actuelle | Conditions du fournisseur vérifiées. Les nouvelles collectes et redistributions nécessitent une autorisation. |
| Mobalytics | Liens d’origine et synthèses de préparation Hexa datées | Conditions vérifiées. L’application ouvre les pages originales dans le navigateur. |
| TFT Academy | Annuaire et consultation d’origine | Conditions consultées. Aucun flux autorisé identifié pour ce projet. |
| TFTips et Tactics.tools | Annuaire et références expérimentales | Les pages de calendrier ou de changements PBE ne confirment pas les performances d’une composition. |
| MetaTFT et Sologesang | Consultation d’origine et lien depuis des plans éditoriaux | Les classements experts et les statistiques ne sont pas importés ni fusionnés. |
| TFT Flow, TFT Codex, TFT Ninja, La Casita del TFT, BunnyMuffins | Consultation d’origine | Pages publiques repérées. Autorisation d’import non établie pour ce projet. |
| TFTable, HexComps, TFT Handbook, TFTraits | Consultation d’origine | Pages publiques repérées. Autorisation d’import non établie pour ce projet. |
| Compete TFT | Liens vers les tableaux des tournois | Le flux de points par manche reste à obtenir. |

## Actualisation

Hexa vérifie les sources en premier plan sans action manuelle. Les vérifications se répètent suivant des intervalles d’au moins 10 minutes pour les catalogues, 5 minutes pour les articles Riot et 3 minutes pour le tracker configuré. Une requête d’actualisation est soumise à iOS pour l’arrière-plan. Le système choisit l’heure d’exécution. Les fichiers valides sont conservés en cas d’échec. Une nouvelle version EUW archive le précédent catalogue de compositions lorsqu’il existe. Les anciennes révisions PBE sont conservées pour comparaison.

## Flux de compositions

Dans **Plus → Flux de compositions**, renseigner l’URL HTTPS d’un export que le fournisseur a autorisé à utiliser. Le corps JSON accepte deux champs facultatifs indépendants, `live` et `pbe`. Aucun secret ne doit être placé dans cette URL.

- `live.provider` identifie la source. `live.pack` suit le format `MetaPack` du projet avec `data`, `patch`, `set` et `retrievedAt`. Chaque composition fournit le build client sous `display_patch` (ex. `16.22`), le contexte d’échantillon et les statistiques réellement observées. Le Codex vient du build vérifié par Hexa.
- `pbe.revision` correspond à l’identifiant de build CommunityDragon sans suffixe, `pbe.set` est le numéro du set en texte et `pbe.retrievedAt` indique la date de collecte. Chaque entrée de `pbe.guides` fournit `id`, `title`, `style`, `core` (liste de noms), `plan`, `source` (URL HTTPS) et `provider`. Une révision différente reste hors de la rubrique active.
- L’import d’archive accepte le format `PatchSnapshot` avec `pack`, `reference` et éventuellement `provider`. Il valide les identifiants et la compatibilité de set avant d’enregistrer.

## Tracker Riot

Le serveur privé `server/tracker.py` utilise Python 3 sans dépendance. Le déployer derrière un proxy HTTPS et définir `RIOT_API_KEY` avec un accès TFT autorisé, puis `HEXA_ACCESS_TOKEN` avec un jeton aléatoire d’au moins 24 caractères. Le service écoute sur l’interface locale au port 8080 par défaut. Il ne doit être rendu accessible que par le proxy, avec limites de requêtes et d’expiration adaptées. Le token Riot reste côté serveur. Le serveur ne conserve pas de profil sur disque.

Sur iPhone, ouvrir **Tracker → Réglages**, saisir le Riot ID, la région, l’adresse HTTPS et le jeton du serveur Hexa. Le jeton est gardé dans le trousseau iOS. Le serveur charge jusqu’à 100 identifiants et complète les matchs par lots d’au plus 20 pour respecter les quotas. L’app conserve les parties déjà reçues, calcule ses statistiques par sélection et enregistre les LP à partir des relevés réellement reçus. L’effacement est disponible dans le Tracker.

## Limites restantes

- Le serveur Riot est livré mais n’est pas hébergé ou relié à un compte réel. Les tests du serveur utilisent des données identifiées comme fixtures.
- Les chiffres LIVE du fournisseur et les guides de la révision PBE active exigent un flux autorisé. Les conditions de Blitz et Mobalytics ne constituent pas une permission de redistribuer leurs guides ou bases. Les sources supplémentaires sont des liens documentés.
- Le comparateur PBE utilise les champs présents dans les exports. Le PBE et les archives n’empruntent pas les statistiques de production.
- Le calendrier esport réunit les dates annoncées et les liens officiels. Les classements, scores manche par manche, horaires précis et listes de joueurs dépendent d’un flux de tournoi vérifié. Les actualités Riot se rafraîchissent automatiquement.
- L’actualisation en arrière-plan dépend d’iOS. La diffusion immédiate à l’app fermée demanderait une infrastructure de notifications et une app signée.
- L’équipe finale d’un match présente les unités réellement reçues. Les coordonnées de placement et un historique de LP antérieur aux relevés ne figurent pas dans les réponses utilisées.
- Les options restantes du cahier des charges incluent les collections avancées, les notifications d’événements, les comparaisons multi-fournisseurs et la couverture exhaustive des historiques et des tournois.

Le workflow GitHub Actions produit une IPA non signée et les résultats de tests. L’IPA requiert une signature pour une installation physique.
