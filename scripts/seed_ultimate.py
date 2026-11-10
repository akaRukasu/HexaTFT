"""Build isolated Ultimate seed snapshots from a captured official/provider export."""
import hashlib
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "HexaTFT" / "Resources"

def write(name, value):
    (RES / name).write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

def read(path):
    return json.loads(path.read_bytes())

def clean(value):
    value = re.sub(r"<br\s*/?>", "\n", value or "", flags=re.I)
    return html.unescape(re.sub(r"%i:[^%]+%|<[^>]+>", "", value)).strip()

def make_reference(raw, number, revision, retrieved, source, art_root):
    content = next(s for s in raw["setData"] if s["mutator"] == f"TFTSet{number}")
    all_items = {i["apiName"]: i for i in raw["items"] if i.get("apiName")}
    entries = {}
    def add(kind, key, name, image, desc, cost=0, components=None, tags=None):
        if not key or not name:
            return
        art = image.lower().removesuffix(".tex") + ".png" if (image or "").endswith(".tex") else (image or "").lower()
        entries[f"{kind}:{key}"] = dict(id=f"{kind}:{key}",name=name,kind=kind,set=str(number),cost=cost or 0,
            description=clean(desc),imageURL=art_root+art if art.startswith("assets/") else "",components=components,itemTags=tags)
    for c in content["champions"]:
        key=c.get("apiName")
        name=c.get("name") or ""
        if key and key.endswith(("_AD","_AP")) and name:
            name += f" ({key[-2:]})"
        add("champion",key,name,c.get("squareIcon") or c.get("icon"),(c.get("ability") or {}).get("desc"),c.get("cost"))
    for t in content["traits"]:
        add("trait",t.get("apiName"),t.get("name"),t.get("icon"),t.get("desc"))
    for kind, keys in [("item",content["items"]),("augment",content["augments"])]:
        for key in keys:
            v=all_items.get(key,{})
            add(kind,key,v.get("name"),v.get("icon"),v.get("desc"),components=v.get("composition") if kind=="item" else None,tags=v.get("tags"))
    return dict(version=revision, source=source, retrievedAt=retrieved, entries=list(entries.values()))

def seed(captures):
    archive=read(RES/"meta.json")
    base=read(RES/"reference.json")
    page=(captures/"blitz-current.download").read_text(encoding="utf-8")
    patch=re.search(r"Patch (\d+\.\d+[a-z]?)",page).group(1)
    number=int(re.search(r"TFT Set (\d+)",page).group(1))
    matches=[json.loads(json.loads(body)["body"]) for attrs,body in re.findall(r"<script([^>]*)>(.*?)</script>",page,re.S)
             if "data-sveltekit-fetched" in attrs and "/analyzed_comps?" in attrs]
    assert len(matches)==1
    timestamp="2026-11-10"
    live_version=read(captures/"live-meta.download")["version"].split("+")[0]
    pbe_version=read(captures/"pbe-meta.download")["version"].split("+")[0]
    assert {c["display_patch"] for c in matches[0]["data"]} == {".".join(live_version.split(".")[:2])}
    assert read(captures/"riot-euw.download")["v"].startswith(".".join(live_version.split(".")[:2])+".")
    live_raw=read(captures/"live.download")
    pbe_raw=read(captures/"pbe.download")
    live_tag=".".join(live_version.split(".")[:2])
    live_ref=make_reference(live_raw,number,live_version,timestamp,f"https://raw.communitydragon.org/{live_tag}/cdragon/tft/fr_fr.json",f"https://raw.communitydragon.org/{live_tag}/game/")
    old={e["id"]:e for e in base["entries"]}
    # Keep the established French names and complete localized recipes when the new
    # export gives the same item recipe. Patch-specific descriptions stay isolated.
    for e in live_ref["entries"]:
        prior=old.get(e["id"])
        if prior and not e["components"] and prior.get("components"):
            e["components"]=prior["components"]
    champion_keys={e["id"].split(":",1)[1] for e in live_ref["entries"] if e["kind"]=="champion"}
    fields=set(archive["data"][0])
    data=[{k:v for k,v in c.items() if k in fields} for c in matches[0]["data"] if all(u["name"] in champion_keys for u in c["units"])]
    assert data
    write("live-meta.json",dict(data=data,patch=patch,set=str(number),retrievedAt=timestamp))
    write("live-reference.json",live_ref)
    write("pbe-reference.json",make_reference(pbe_raw,number,pbe_version,timestamp,
        "https://raw.communitydragon.org/pbe/cdragon/tft/fr_fr.json","https://raw.communitydragon.org/pbe/game/"))
    write("ultimate-context.json",dict(liveBuild=live_version,pbeBuild=pbe_version,pbeObservedAt="2026-11-09",
        pbeDigest=hashlib.sha256((captures/"pbe.download").read_bytes()).hexdigest(),euwAssetVersion=read(captures/"riot-euw.download")["v"]))
    print(f"LIVE {patch}: {len(data)} compositions, {len(live_ref['entries'])} entrées. PBE: {pbe_version}.")

if __name__ == "__main__":
    seed(ROOT / "research")
