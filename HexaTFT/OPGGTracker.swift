import Foundation

enum OPGGTracker {
    enum ReadError: LocalizedError {
        case missingProfile(String), unreadable(String), differentAccount(String)
        var errorDescription: String? {
            switch self {
            case .missingProfile(let server): return "OP.GG ne trouve pas ce compte sur \(server). Vérifie le Riot ID complet et le serveur sélectionné."
            case .unreadable(let server): return "La réponse OP.GG pour \(server) ne contient pas encore de fiche lisible. Réessaie la récupération ; les données enregistrées sont conservées."
            case .differentAccount(let server): return "La fiche reçue ne correspond pas au compte demandé sur \(server). Aucun autre compte n’a été importé."
            }
        }
    }
    static func fetch(_ identity: RiotIdentity) async throws -> RiotProfile {
        #if DEBUG
        if let html = ProcessInfo.processInfo.environment["HEXA_OPGG_TRACKER_FIXTURE"] { return try parse(html,identity:identity) }
        #endif
        guard let url = profileURL(identity) else { throw DataIssue.invalid("Ce serveur TFT n’est pas disponible sur OP.GG.") }
        return try await load(url, identity: identity)
    }

    static func profileURL(_ identity: RiotIdentity, set: Int? = nil) -> URL? {
        guard let base = identity.opggProfile, var parts = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return nil }
        parts.queryItems = [URLQueryItem(name: "queueType", value: "RANKED_TFT")]
        if let set { parts.queryItems?.append(URLQueryItem(name: "set", value: String(set))) }
        return parts.url
    }

    private static func load(_ url: URL, identity: RiotIdentity) async throws -> RiotProfile {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField:"Cache-Control")
        request.httpShouldHandleCookies = false
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.url?.host == "op.gg" else {
            throw DataIssue.invalid("La fiche publique OP.GG est indisponible.")
        }
        if http.statusCode == 404 { throw DataIssue.invalid("Compte introuvable sur OP.GG. Vérifie le Riot ID et le serveur.") }
        guard http.statusCode == 200, data.count <= 8_000_000,
              let html = String(data: data, encoding: .utf8) else {
            throw DataIssue.invalid("OP.GG est momentanément indisponible.")
        }
        return try await Task.detached(priority: .utility) { try parse(html, identity: identity) }.value
    }

    static func parse(_ html: String, identity: RiotIdentity, checkedAt: Date = .now) throws -> RiotProfile {
        let page = OPGGPublicPage(html)
        guard let data = page.payload(containing: ["profile", "selectedSet"]) else { throw ReadError.unreadable(identity.regionName) }
        guard let profile = page.object(data["profile"]) else {
            if ["not_found", "not-found", "notFound", "missing"].contains(data["status"] as? String ?? "") { throw ReadError.missingProfile(identity.regionName) }
            throw ReadError.unreadable(identity.regionName)
        }
        guard let name = page.resolve(profile["gameName"]) as? String,
              let tag = page.resolve(profile["tagLine"]) as? String,
              let rawRegion = page.resolve(profile["region"]) as? String,
              let region = RiotIdentity.regions.first(where: { $0.0 == rawRegion.lowercased() || $0.2 == rawRegion.lowercased() })?.2,
              let timestamp = page.resolve(profile["updatedAt"]) as? String, let updated = timestampDate(timestamp) else {
            throw ReadError.unreadable(identity.regionName)
        }
        guard region == identity.opggProfile?.pathComponents.dropLast().last,
              (name + "#" + tag).caseInsensitiveCompare(identity.riotID) == .orderedSame else { throw ReadError.differentAccount(identity.regionName) }
        let ranks = (page.resolve(profile["ranks"]) as? [Any] ?? []).compactMap { entry -> RiotProfile.Rank? in
            guard let fields = page.object(entry), let queue = fields["queueType"] as? String,
                  let tier = fields["tier"] as? String, let points = fields["points"] as? Int,
                  fields["pointsType"] as? String == "LP" else { return nil }
            return RiotProfile.Rank(queue: queue, tier: tier, division: fields["division"] as? String ?? "",
                                    lp: points, wins: nil, losses: nil, games: fields["games"] as? Int,
                                    top4Count: fields["top4Count"] as? Int, rankPosition: fields["rankPosition"] as? Int)
        }
        let matchData = page.object(data["matches"])
        let rawMatches = page.resolve(matchData?["matches"]) as? [Any] ?? []
        let matches = rawMatches.compactMap { parseMatch($0, page: page, platform: region) }
        let points = data["queueType"].flatMap { $0 as? String }.map { queue in
            parsePoints(page.object(data["lpHistory"]), page: page, queue: queue)
        }
        guard rawMatches.isEmpty || !matches.isEmpty else {
            throw DataIssue.invalid("Le format de l’historique OP.GG a changé. La dernière synchronisation est conservée.")
        }
        return RiotProfile(id: identity.trackerID, riotID: name + "#" + tag, region: identity.region,
                           observedAt: updated.timeIntervalSince1970, matches: matches, ranks: ranks,
                           source: "OP.GG", checkedAt: checkedAt, publishedPoints: points,
                           seasons: parseSeasons(data, page: page), currentSet: data["selectedSet"] as? Int,
                           indexedGames: page.object(page.object(data["season"])?["summary"])?["games"] as? Int)
    }

    private static func parseSeasons(_ data: [String: Any], page: OPGGPublicPage) -> [SeasonRecord] {
        guard let profile = page.object(data["profile"]) else { return [] }
        let available = (page.resolve(data["seasons"]) as? [Any] ?? []).compactMap { page.object($0) }
        return (page.resolve(profile["previousSeasons"]) as? [Any] ?? []).compactMap { value in
            guard let row = page.object(value), let id = row["setName"] as? String,
                  let number = available.first(where: { $0["setName"] as? String == id })?["set"] as? NSNumber else { return nil }
            let ranks = (page.resolve(row["ranks"]) as? [Any] ?? []).compactMap { entry -> RiotProfile.Rank? in
                guard let fields = page.object(entry), let queue = fields["queueType"] as? String,
                      let tier = fields["tier"] as? String, let lp = fields["points"] as? Int,
                      fields["pointsType"] as? String == "LP" else { return nil }
                return RiotProfile.Rank(queue: queue, tier: tier, division: fields["division"] as? String ?? "", lp: lp,
                                        wins: nil, losses: nil, games: fields["games"] as? Int, top4Count: fields["top4Count"] as? Int)
            }
            return SeasonRecord(id: id, number: number.stringValue, ranks: ranks)
        }
    }

    static func fetchArchive(_ identity: RiotIdentity, set: Int) async throws -> SeasonArchive {
        guard let url = profileURL(identity, set: set) else { throw DataIssue.invalid("Archive indisponible.") }
        let data = try await DragonFeed.get(url, max: 8_000_000)
        guard let html = String(data: data, encoding: .utf8) else { throw DataIssue.invalid("Archive illisible.") }
        return try await Task.detached(priority: .utility) { try parseArchive(html, identity: identity, set: set) }.value
    }

    static func parseArchive(_ html: String, identity: RiotIdentity, set: Int, checkedAt: Date = .now) throws -> SeasonArchive {
        let profile = try parse(html, identity: identity, checkedAt: checkedAt)
        let page = OPGGPublicPage(html)
        guard profile.currentSet == set, let data = page.payload(containing: ["profile", "selectedSet"]),
              data["queueType"] as? String == "RANKED_TFT" else { throw DataIssue.invalid("Cette archive solo n’est pas fournie pour le set demandé.") }
        let summary = page.object(page.object(data["season"])?["summary"])
        let counts = page.resolve(summary?["placements"]) as? [Int]
        let count = summary?["games"] as? Int
        let valid = counts?.count == 8 && counts?.reduce(0,+) == count && counts?.allSatisfy({ $0 >= 0 }) == true
        return SeasonArchive(set: set, matches: profile.matches.filter { $0.set == set && $0.queue == 1100 }, checkedAt: checkedAt,
                             indexedGames: valid ? count : nil, indexedTop4: valid ? counts?.prefix(4).reduce(0,+) : nil)
    }

    private static func parseMatch(_ value: Any, page: OPGGPublicPage, platform: String) -> TrackedMatch? {
        guard let fields = page.object(value), let id = fields["id"] as? String,
              let rawRegion = fields["region"] as? String,
              RiotIdentity.regions.first(where: { $0.0 == rawRegion.lowercased() || $0.2 == rawRegion.lowercased() })?.2 == platform,
              let time = fields["playedAt"] as? Double, time > 0,
              let placement = (fields["displayPlacement"] ?? fields["placement"]) as? Int,
              (1...8).contains(placement) else { return nil }
        let units = (page.resolve(fields["units"]) as? [Any] ?? []).compactMap { value -> TrackedMatch.Unit? in
            guard let unit = page.object(value), let key = unit["key"] as? String else { return nil }
            let rawEquipment = page.resolve(unit["items"]) as? [Any]
            let equipment = (rawEquipment ?? []).compactMap { value -> MatchItem? in
                guard let item = page.object(value), let key = item["key"] as? String else { return nil }
                return MatchItem(key: key, name: item["name"] as? String ?? key, category: item["category"] as? String,
                                 imageURL: item["imageUrl"] as? String,
                                 components: (page.resolve(item["componentItems"]) as? [Any])?.compactMap { page.object($0)?["name"] as? String },
                                 effect: item["description"] as? String)
            }
            let stats = page.object(unit["combatStats"])
            return TrackedMatch.Unit(key: key, stars: unit["star"] as? Int, items: equipment.map(\.key), name: unit["name"] as? String,
                                     equipment: rawEquipment == nil ? nil : equipment, cost: unit["cost"] as? Int, range: stats?["range"] as? Double,
                                     imageURL: unit["imageUrl"] as? String)
        }
        let traits = (page.resolve(fields["traits"]) as? [Any] ?? []).compactMap { value -> TrackedMatch.Trait? in
            guard let trait = page.object(value), let key = trait["key"] as? String, let count = trait["count"] as? Int else { return nil }
            return TrackedMatch.Trait(key: key, count: count, tier: trait["style"] as? Int ?? 0, name: trait["name"] as? String)
        }
        return TrackedMatch(id: id, timestamp: time / 1_000, patch: fields["version"] as? String, set: fields["set"] as? Int,
                            queue: fields["queueId"] as? Int, mode: fields["queueName"] as? String, placement: placement,
                            level: fields["level"] as? Int, units: units, traits: traits, augments: [], lobby: [],
                            duration: fields["durationSeconds"] as? Double, lastRound: fields["lastRound"] as? Int,
                            goldLeft: fields["goldLeft"] as? Int, playerDamage: fields["damage"] as? Int,
                            playersEliminated: fields["playersEliminated"] as? Int, source: "OP.GG", augmentsKnown: false)
    }

    private static func parsePoints(_ history: [String: Any]?, page: OPGGPublicPage, queue: String) -> [RankPoint] {
        guard history?["period"] as? String == "day", let points = page.resolve(history?["points"]) as? [Any] else { return [] }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return points.compactMap { value in
            guard let fields = page.object(value), let day = fields["date"] as? String,
                  let date = formatter.date(from: day), let tier = fields["tier"] as? String,
                  let lp = fields["leaguePoints"] as? Int else { return nil }
            return RankPoint(date: date, rank: .init(queue: queue, tier: tier, division: fields["division"] as? String ?? "",
                                                   lp: lp, wins: nil, losses: nil))
        }
    }

    static func timestampDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.remove(.withFractionalSeconds)
        return formatter.date(from: value)
    }
}

// Read the JSON that powers the public page, without running its scripts.
struct OPGGPublicPage {
    private let rows: [String: Any]

    init(_ html: String) {
        let pattern = #"self\.__next_f\.push\((\[\s*1\s*,.*?)\)\s*</script>"#
        let regex = try! NSRegularExpression(pattern: pattern, options:[.dotMatchesLineSeparators])
        let chunks = regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: html),
                  let array = try? JSONSerialization.jsonObject(with: Data(html[range].utf8)) as? [Any],
                  array.count == 2 else { return nil }
            return array[1] as? String
        }
        var rows: [String: Any] = [:]
        for line in chunks.joined().split(separator: "\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon])
            let payload = line[line.index(after: colon)...]
            guard Int(key, radix: 16) != nil,
                  let value = try? JSONSerialization.jsonObject(with: Data(payload.utf8), options:[.fragmentsAllowed]) else { continue }
            rows[key] = value
        }
        self.rows = rows
    }

    func payload(containing keys: [String]) -> [String: Any]? {
        func find(_ value: Any, depth: Int) -> [String: Any]? {
            guard depth > 0 else { return nil }
            if let object = value as? [String: Any] {
                if let data = self.object(object["data"]), keys.allSatisfy({ data[$0] != nil }) { return data }
                if let children = object["children"] { return find(children, depth: depth - 1) }
            }
            if let view = value as? [Any], view.count == 4, view.first as? String == "$" {
                return find(view[3], depth: depth - 1)
            }
            return nil
        }
        for key in rows.keys.sorted() {
            if let row = rows[key], let data = find(row, depth: 8) { return data }
        }
        return nil
    }

    func object(_ value: Any?) -> [String: Any]? { resolve(value) as? [String: Any] }

    func resolve(_ value: Any?, depth: Int = 0) -> Any? {
        guard let reference = value as? String, reference.hasPrefix("$") else { return value }
        if reference.hasPrefix("$D") { return String(reference.dropFirst(2)) }
        if reference.hasPrefix("$$") { return String(reference.dropFirst()) }
        let path = reference.dropFirst().split(separator: ":")
        guard depth < 16, let id = path.first else { return nil }
        let key = id.first == "@" || id.first == "L" ? String(id.dropFirst()) : String(id)
        guard var result = rows[key] else { return nil }
        for key in path.dropFirst() {
            if let object = result as? [String: Any], let next = object[String(key)] { result = next }
            else if let array = result as? [Any], let index = key == "props" ? 3 : Int(key), array.indices.contains(index) { result = array[index] }
            else { return nil }
        }
        return resolve(result, depth: depth + 1)
    }
}
