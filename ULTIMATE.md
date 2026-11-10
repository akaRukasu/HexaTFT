# HexaTFT Ultimate 0.6.2

## Audit et périmètre

La version 0.3 mélangeait un seul catalogue de compositions et un seul Codex avec un cache global. Ultimate isole les versions de production, les révisions expérimentales et les archives. Les guides interactifs, favoris, plateaux personnels, recettes et notes existants sont conservés. La copie vers l’atelier utilise le Codex compatible avec ses données historiques.

Le dépôt livre un Codex EUW vérifié par la version des ressources Riot, le Codex PBE de CommunityDragon, un comparateur, les notes éditoriales Riot, le calendrier et les actualités esport, un tracker iOS et un serveur Riot privé. Le patch LIVE 18.6 présente dix-huit guides originaux Hexa, avec progression visuelle, équipement par champion, recettes, transitions et plans de secours. Ils ne comportent aucune statistique de performance. Les 48 guides observés sur 18.5 restent accessibles dans Archives. Les nouvelles données natives de composition proviennent d’un flux HTTPS autorisé. Les pages d’origine restent consultables dans l’annuaire. Les PBE historiques de Mobalytics sont des synthèses Hexa datées avec des liens. Les guides du nouveau build apparaissent lorsque le flux autorisé en fournit. L’atelier de synergies lit directement les unités et paliers du build PBE.

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

## Accueil, patches et esport

L’accueil affiche les cartes statistiques par source avec les chiffres sous les portraits. L’onglet Guides présente les compositions jouables. Le Radar présente une sélection éditoriale de dix-sept mesures publiques relevées le 10 novembre 2026 chez TFT Codex, Tactics.Tools et MetaStats.gg. La période, le rang et le lien d’origine accompagnent chaque relevé. La mention du patch 18.6 est conservée après un changement de patch. Le filtre de MetaStats.gg peut regrouper plusieurs versions, comme indiqué par le fournisseur. Hexa ne recalcule pas de classement commun à ces sources. Chaque carte du Radar inclus ouvre directement un guide natif sur son plateau final. Le guide précise que les placements et objets sont proposés par Hexa. Les cartes archivées ouvrent leur plateau avec le Codex du patch correspondant.

Les fiches des patches 18.5 et 18.6 résument les changements de Riot avec catégories et valeurs avant/après. Le fil officiel détecte de nouvelles publications. À l’ouverture d’une nouvelle note, Hexa lit les valeurs avant/après quand elles sont structurées dans la page Riot. L’esport distingue résultats de tournoi, ladder daté et effectifs des clubs français vérifiés. Le calendrier regroupe les prochaines compétitions et les événements terminés. Le catalogue PBE génère des noyaux de trait avec des plateaux interactifs à partir du Codex expérimental.

## Actualisation

Hexa vérifie les sources en premier plan sans action manuelle. Les vérifications se répètent suivant des intervalles d’au moins 10 minutes pour les catalogues, 5 minutes pour les articles Riot et 3 minutes pour le tracker configuré. Une requête d’actualisation est soumise à iOS pour l’arrière-plan. Le système choisit l’heure d’exécution. Les fichiers valides sont conservés en cas d’échec. Une nouvelle version EUW archive le précédent catalogue de compositions lorsqu’il existe. Les anciennes révisions PBE sont conservées pour comparaison.

## Flux de compositions

Pour distribuer un flux, déclarer l’URL HTTPS de l’export autorisé dans la variable GitHub Actions `HEXA_META_SERVICE`. Les vérifications automatiques démarrent à l’ouverture. Le corps JSON accepte trois champs facultatifs, `live`, `pbe` et `radar`. Aucun secret ne doit être placé dans cette URL.

- `live.provider` identifie la source. `live.pack` suit le format `MetaPack` du projet avec `data`, `patch`, `set` et `retrievedAt`. Chaque composition fournit le build client sous `display_patch` (ex. `16.22`), le contexte d’échantillon et les statistiques réellement observées. Le Codex vient du build vérifié par Hexa.
- `pbe.revision` correspond à l’identifiant de build CommunityDragon sans suffixe, `pbe.set` est le numéro du set en texte et `pbe.retrievedAt` indique la date de collecte. Chaque entrée de `pbe.guides` fournit `id`, `title`, `style`, `core` (liste de noms), `plan`, `source` (URL HTTPS) et `provider`. Le champ facultatif `pbe.catalogue` permet d’ajouter des cartes chiffrées. Il suit le format `PatchSnapshot` et exige un fournisseur, une source HTTPS et la révision PBE complète dans `display_patch` pour chaque composition. Une révision différente reste hors de la rubrique active.
- `radar` met à jour les cartes du Radar. Il fournit `patch`, `build` (branche ou build), `set`, `retrievedAt` (ISO 8601) et `readings`. Chaque relevé exige une source HTTPS du fournisseur, le rang et la période dans `scope` et les chiffres sur une seule population. Le champ facultatif `guideID` désigne le `comp_id` d’un guide du même patch fourni dans `live.pack`. Une carte qui reçoit seulement son noyau affiche les champions fournis et un placement indicatif dans Hexa. Un relevé compatible plus récent remplace le cache local. Avec `nextCursor`, Hexa charge la suite automatiquement via le même point d’accès et le paramètre `cursor`. Les pages du même instantané s’ajoutent sans doublon. Le classement par Top 4 est le défaut et le mode Découverte alterne les sources. Les archives suivent dans des sections séparées par patch.
- L’import d’archive accepte le format `PatchSnapshot` avec `pack`, `reference` et éventuellement `provider`. Il valide les identifiants et la compatibilité de set avant d’enregistrer.

## Tracker Riot

Dans l’app, ouvrir **Tracker → Ajouter mon compte**, puis saisir le Riot ID et la région. Le profil est enregistré sur l’iPhone et la fiche originale Tactics.Tools se charge directement dans le Tracker. La synchronisation native démarre automatiquement lorsque l’édition distribuée comporte un service Riot Hexa actif.

Pour l’exploitation du service Hexa, le serveur Python écoute uniquement sur l’interface locale. Avec le mode proxy public, définir `HEXA_PUBLIC_PROXY=1` et `RIOT_API_KEY` côté serveur, mettre en place un proxy TLS avec limites par client et une surveillance du quota Riot, puis déclarer l’URL HTTPS dans la variable GitHub Actions `HEXA_TRACKER_SERVICE`. L’IPA ne contient que l’URL du service. Le tableau natif regroupe les classements, les filtres par mode et set, les graphiques de placements, le détail des matchs et les LP relevés. Le serveur garde au maximum 32 profils en cache mémoire et complète les données de match par lots de 20. L’app conserve les parties déjà reçues et enregistre les LP à partir des relevés réellement reçus.

## Limites de cette livraison

- Le serveur Riot est livré mais n’est pas hébergé ou relié à un compte réel. Les tests du serveur utilisent des données identifiées comme fixtures.
- Les chiffres LIVE du fournisseur et les guides de la révision PBE active exigent un flux autorisé. Les conditions de Blitz et Mobalytics ne constituent pas une permission de redistribuer leurs guides ou bases. Les sources supplémentaires sont des liens documentés.
- Le comparateur PBE utilise les champs présents dans les exports. Le PBE et les archives n’empruntent pas les statistiques de production.
- Le calendrier esport réunit les dates annoncées et les liens officiels. Les classements, scores manche par manche, horaires précis et listes de joueurs dépendent d’un flux de tournoi vérifié. Les actualités Riot se rafraîchissent automatiquement.
- L’actualisation en arrière-plan dépend d’iOS. La diffusion immédiate à l’app fermée demanderait une infrastructure de notifications et une app signée.
- L’équipe finale d’un match présente les unités réellement reçues. Les coordonnées de placement et un historique de LP antérieur aux relevés ne figurent pas dans les réponses utilisées.
- Les options restantes du cahier des charges incluent les collections avancées, les notifications d’événements, les comparaisons multi-fournisseurs et la couverture exhaustive des historiques et des tournois.

Le workflow GitHub Actions produit une IPA non signée et les résultats de tests. L’IPA requiert une signature pour une installation physique.
