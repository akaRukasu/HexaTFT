"""Private Riot tracker gateway. Deploy behind a TLS reverse proxy."""
import hmac
import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode, urlsplit
from urllib.request import Request, urlopen

REGIONS = {"euw1":"europe", "eun1":"europe", "tr1":"europe", "ru":"europe", "me1":"europe",
           "na1":"americas", "br1":"americas", "la1":"americas", "la2":"americas",
           "kr":"asia", "jp1":"asia", "oc1":"sea", "sg2":"sea", "tw2":"sea", "vn2":"sea"}
CACHE = {}
BUDGET = []
KEY = os.environ.get("RIOT_API_KEY", "")
TOKEN = os.environ.get("HEXA_ACCESS_TOKEN", "")

class GatewayError(Exception):
    def __init__(self, code, message):
        self.code, self.message = code, message

def riot(host, path):
    now = time.monotonic()
    BUDGET[:] = [t for t in BUDGET if now-t < 120]
    if len(BUDGET) >= 90:
        raise GatewayError(429, "Quota local atteint. Réessaie dans deux minutes.")
    burst = [t for t in BUDGET if now-t < 1]
    if len(burst) >= 18:
        time.sleep(max(0, 1.05-(now-burst[0])))
    BUDGET.append(time.monotonic())
    try:
        request = Request(f"https://{host}.api.riotgames.com{path}", headers={"X-Riot-Token":KEY})
        with urlopen(request, timeout=8) as response:
            data = response.read(4_000_001)
            if len(data) > 4_000_000:
                raise GatewayError(502, "Réponse Riot trop volumineuse.")
            return json.loads(data)
    except HTTPError as e:
        if e.code == 429:
            raise GatewayError(429, "Quota Riot atteint. Réessaie dans quelques minutes.") from e
        if e.code in (401,403):
            raise GatewayError(503, "Le serveur n’a pas accès à cette API Riot.") from e
        if e.code == 404:
            raise GatewayError(404, "Profil ou données introuvables sur cette région.") from e
        raise GatewayError(502, "L’API Riot est momentanément indisponible.") from e
    except (URLError, TimeoutError, ValueError) as e:
        raise GatewayError(502, "Réponse Riot indisponible.") from e

def normalized_match(doc, puuid):
    info = doc["info"]
    participants = info.get("participants", [])
    player = next((p for p in participants if p.get("puuid") == puuid), None)
    if not player or not 1 <= player.get("placement",0) <= 8:
        return None
    return {
        "id":doc["metadata"]["match_id"], "timestamp":info["game_datetime"]/1000,
        "patch":info.get("game_version"), "set":info.get("tft_set_number"), "queue":info.get("queue_id"),
        "mode":info.get("tft_game_type"), "placement":player["placement"], "level":player.get("level"),
        "units":[{"key":u.get("character_id",""),"stars":u.get("tier"),"items":u.get("itemNames") or []}
                 for u in player.get("units",[])],
        "traits":[{"key":t.get("name",""),"count":t.get("num_units",0),"tier":t.get("tier_current",0)}
                  for t in player.get("traits",[]) if t.get("tier_current",0)>0],
        "augments":player.get("augments") or [],
        "lobby":[{"placement":p.get("placement",0),"name":p.get("riotIdGameName") or "Joueur"}
                 for p in participants],
    }

def tracker(body):
    name, tag, region = (body.get(k) for k in ("name","tag","region"))
    if not all(isinstance(v,str) for v in (name,tag,region)) or region not in REGIONS or not 1 <= len(name) <= 32 or not 1 <= len(tag) <= 12:
        raise GatewayError(400, "Riot ID ou région invalide.")
    host = REGIONS[region]
    account_host = "asia" if host == "sea" else host
    cache_key = (region, name.casefold(), tag.casefold())
    now = time.time()
    cached = CACHE.get(cache_key)
    if cached and now-cached["observedAt"] < 120:
        return cached
    account = riot(account_host, "/riot/account/v1/accounts/by-riot-id/"+quote(name,safe="")+"/"+quote(tag,safe=""))
    puuid = quote(account["puuid"],safe="")
    ranks = riot(region, "/tft/league/v1/by-puuid/"+puuid)
    ids = riot(host, "/tft/match/v1/matches/by-puuid/"+puuid+"/ids?"+urlencode({"start":0,"count":100}))
    known = {m["id"]:m for m in cached["matches"]} if cached else {}
    matches = []
    remaining = 20
    for id_ in ids:
        if id_ not in known:
            if remaining == 0:
                continue
            remaining -= 1
        try:
            match = known[id_] if id_ in known else normalized_match(
                riot(host,"/tft/match/v1/matches/"+quote(id_,safe="")),account["puuid"])
        except GatewayError as e:
            if e.code == 404:
                continue
            raise
        if match:
            matches.append(match)
    result = {"id":account["puuid"],"riotID":(account.get("gameName") or name)+"#"+(account.get("tagLine") or tag),
              "region":region, "observedAt":now, "matches":matches,
              "ranks":[{"queue":r["queueType"],"tier":r["tier"],"division":r["rank"],"lp":r["leaguePoints"],
                        "wins":r["wins"],"losses":r["losses"]} for r in ranks if "leaguePoints" in r]}
    if len(CACHE) >= 32 and cache_key not in CACHE:
        CACHE.pop(next(iter(CACHE)))
    CACHE[cache_key] = result
    return result

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        self.connection.settimeout(10)
        try:
            if urlsplit(self.path).path != "/v1/tracker":
                raise GatewayError(404,"Route inconnue.")
            auth = self.headers.get("Authorization","").encode()
            if not hmac.compare_digest(auth, ("Bearer "+TOKEN).encode()):
                raise GatewayError(401,"Jeton d’accès au serveur invalide.")
            size = int(self.headers.get("Content-Length",0))
            if not 0 < size <= 1024:
                raise GatewayError(400,"Requête invalide.")
            body = json.loads(self.rfile.read(size))
            if not isinstance(body,dict):
                raise GatewayError(400,"Requête invalide.")
            self.send_json(200,tracker(body))
        except GatewayError as e:
            self.send_json(e.code,{"error":e.message})
        except (ValueError,KeyError,TypeError,TimeoutError):
            self.send_json(502,{"error":"Format de réponse ou de requête invalide."})

    def send_json(self, code, body):
        payload = json.dumps(body,ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type","application/json; charset=utf-8")
        self.send_header("Cache-Control","no-store")
        self.send_header("Content-Length",str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

if __name__ == "__main__":
    if not KEY or len(TOKEN)<24:
        raise SystemExit("Configurer RIOT_API_KEY et HEXA_ACCESS_TOKEN (24 caractères ou plus).")
    HTTPServer(("127.0.0.1",int(os.environ.get("HEXA_PORT","8080"))),Handler).serve_forever()
