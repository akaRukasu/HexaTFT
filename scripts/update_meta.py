"""Refresh native Blitz data and the French reference for its advertised set."""
import concurrent.futures, datetime, html, json, re, urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RES=ROOT/'HexaTFT/Resources'
def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'HexaTFT/0.2'}),timeout=40).read()
def clean(s):
    s=re.sub(r'<br\s*/?>','\n',s or '')
    return html.unescape(re.sub(r'%i:[^%]+%|<[^>]+>','',s)).strip()
def main():
    page=fetch('https://blitz.gg/tft/comps').decode()
    set_number=re.search(r'TFT Set (\d+)',page).group(1)
    display_patch=re.search(r'Patch (\d+\.\d+)',page).group(1)
    payload=None
    for attrs,body in re.findall(r'<script([^>]*)>(.*?)</script>',page,re.S):
        if 'data-sveltekit-fetched' in attrs and '/analyzed_comps?' in html.unescape(attrs):
            payload=json.loads(json.loads(body)['body'])
    assert payload and payload['data']
    # Keep the source structures consumed by the app, including real boards by level/stage.
    keep={'comp_id','slug','stats','units','units_positions','carry_units','traits','strategy','variations','augments','carry_item_holders','units_stats','display_patch','rank','region','status'}
    payload={'data':[{k:v for k,v in x.items() if k in keep} for x in payload['data']], 'retrievedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'set':set_number,'patch':display_patch}
    (RES/'meta.json').write_text(json.dumps(payload,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    entries=[]
    for kind,endpoint in [('champion','units'),('item','items'),('trait','traits'),('augment','augments')]:
        data=json.loads(fetch(f'https://utils.iesdev.com/static/json/tftTest/set{set_number}/fr_fr/{endpoint}'))
        if kind=='augment': data={k:v for tier in data.values() for k,v in tier.items()}
        for key,v in data.items():
            path={'champion':f'centered-tft/set{set_number}','item':f'tft/items/set{set_number}','trait':'tft/traits/dark','augment':f'tft/augments/set{set_number}'}[kind]
            desc=v.get('ability',{}).get('description','') if kind=='champion' else v.get('description','')
            if kind=='trait':desc+='\n'+'\n'.join(f"({b['needed']}) {b['effect']}" for b in v.get('bonuses',[]))
            if kind=='item' and v.get('buildsFrom'):desc+='\nRecette : '+' + '.join(data.get(k,{}).get('name',k) for k in v['buildsFrom'])
            entries.append(dict(id=f'{kind}:{key}',name=v['name'] + (' ('+key.rsplit('_',1)[1]+')' if kind=='champion' and key.endswith(('_AD','_AP')) else ''),kind=kind,set=set_number,cost=v.get('cost',0),description=clean(desc),imageURL=f'https://blitz-cdn.blitz.gg/blitz/{path}/{key}.webp'))
    reference=dict(version=f'Set {set_number} · {display_patch}',source='https://blitz.gg/tft/comps',retrievedAt=payload['retrievedAt'],entries=entries)
    (RES/'reference.json').write_text(json.dumps(reference,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
    # Bundle portraits and item icons so native boards also work offline.
    images=ROOT/'HexaTFT/Assets.xcassets';images.mkdir(exist_ok=True)
    def download(e):
        if e['kind'] not in ('champion','item'):return
        name=e['id'].split(':',1)[1];folder=images/(name+'.imageset');folder.mkdir(exist_ok=True)
        try:
            from PIL import Image
            import io
            image=Image.open(io.BytesIO(fetch(e['imageURL']))).convert('RGBA');image.thumbnail((160,160));image.save(folder/'image.png')
            (folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'image.png','idiom':'universal'}],'info':{'author':'xcode','version':1}}))
        except Exception as error: print('Image unavailable',name,str(error))
    list(concurrent.futures.ThreadPoolExecutor(max_workers=10).map(download,entries))
    print(f"Saved {len(payload['data'])} compositions; {len(entries)} French entries; set {set_number}, patch {display_patch}")
if __name__=='__main__':main()
