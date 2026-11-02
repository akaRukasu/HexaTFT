"""Educational guides, not a current-patch meta feed."""
import json
from pathlib import Path

stages=['2-1','2-5','3-2','4-1','5-1','6-1']
styles=[
 ('reroll-one','Reroll à 1 PO','Reroll','Accessible','Un plan pédagogique centré sur les unités peu coûteuses et les améliorations trois étoiles.',
  ['Niv. 4 : repère indicatif','Niv. 4–5 : selon le plan','Niv. 5 : souvent le palier de recherche','Niv. 6 si le noyau est terminé','Niv. 7–8 : compléter les synergies','Plateau final à consolider'],
  ['Comprendre les probabilités de boutique.','Comparer économie et progression du noyau.','Dépenser les intérêts sans épuiser toute la réserve.','Éviter de rester bloqué sur une recherche interminable.','Ajouter de la valeur autour du noyau.','Affiner le placement.']),
 ('reroll-two','Reroll à 2 PO','Slow roll','Intermédiaire','Un plan pédagogique pour comprendre le rôle du niveau 6 et les compromis entre économie et améliorations.',
  ['Niv. 4 : plateau de transition','Niv. 5 : transition possible','Niv. 6 : palier fréquent','Niv. 6–7 : terminer ou évoluer','Niv. 7–8 : compléter le plateau','Valeur des améliorations finales'],
  ['Jouer un plateau de transition cohérent.','Garder des options de porteurs temporaires.','Comprendre le slow roll au palier choisi.','Comparer la poursuite des trois étoiles et la montée en niveau.','Renforcer les synergies et la première ligne.','Comparer plusieurs placements.']),
 ('fast-eight','Construire vers le niveau 8','Fast 8','Intermédiaire','Un plan pédagogique pour passer d’un plateau temporaire à une composition plus coûteuse.',
  ['Niv. 4 : ouverture','Niv. 5 : repère de transition','Niv. 6 : repère courant','Niv. 7–8 : transition à préparer','Niv. 8 : stabilisation puis améliorations','Niv. 9 éventuel, selon les moyens'],
  ['Construire une base économique.','Associer économie et plateau temporaire.','Préparer plusieurs sorties possibles.','Anticiper le transfert des objets.','Améliorer les pièces décisives.','Comparer une unité supplémentaire et les améliorations.'])]
guides=[]
for id,name,style,difficulty,summary,levels,goals in styles:
 phases=[]
 for i,stage in enumerate(stages):
  phases.append(dict(stage=stage,level=levels[i],economy='50 PO : repère classique d’intérêts, à adapter aux règles et au contexte.' if 1<i<5 else 'Préserver les intérêts quand cela reste compatible avec le plateau.',objective=goals[i],options=['Ce palier est un repère de guide, pas une instruction personnalisée.','Option économie : conserver davantage de ressources pour les prochains paliers.','Option stabilité : investir une partie des ressources pour renforcer le plateau.']))
 guides.append(dict(id=id,name=name,style=style,difficulty=difficulty,summary=summary,tags=[style,'Pédagogie','Économie'],itemNotes=['Comparer les besoins de dégâts et de résistance du plateau.','Un porteur temporaire permet de préparer un transfert d’équipement.','Les meilleurs objets dépendent des champions et du patch : aucune liste méta n’est fournie dans cet exemple.'],positioning=['Répartir les tanks et protéger les porteurs de dégâts.','Comparer un carry en coin et une position plus centrale.','Les particularités de chaque set peuvent modifier ces principes.'],phases=phases))
out=dict(schemaVersion=1,patch='Pédagogie · indépendant du patch',updatedAt='2026-11-03',source='Exemples rédigés pour le prototype Hexa ; aucune statistique de méta.',isDemo=True,guides=guides)
root=Path(__file__).resolve().parents[1]
(root/'HexaTFT/Resources/catalogue.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
