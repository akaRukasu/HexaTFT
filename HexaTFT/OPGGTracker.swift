import Foundation

enum OPGGTracker {
    static func fetch(_ identity: RiotIdentity) async throws -> RiotProfile {
        guard let url = identity.opggProfile else { throw DataIssue.invalid("Ce serveur TFT n’est pas disponible sur OP.GG.") }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
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
        guard let data = page.payload(containing: ["profile", "selectedSet"]), let profile = page.object(data["profile"]),
              let name = profile["gameName"] as? String, let tag = profile["tagLine"] as? String,
              let region = profile["region"] as? String,
              region == identity.opggProfile?.pathComponents.dropLast().last,
              (name + "#" + tag).caseInsensitiveCompare(identity.riotID) == .orderedSame,
              let timestamp = profile["updatedAt"] as? String, let updated = timestampDate(timestamp) else {
            throw DataIssue.invalid("La fiche OP.GG n’a pas pu être lue. Vérifie le Riot ID et le serveur.")
        }
        let ranks = (profile["ranks"] as? [Any] ?? []).compactMap { entry -> RiotProfile.Rank? in
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
        return RiotProfile(id: "opgg:" + identity.riotID.lowercased(), riotID: name + "#" + tag, region: identity.region,
                           observedAt: updated.timeIntervalSince1970, matches: matches, ranks: ranks,
                           source: "OP.GG", checkedAt: checkedAt, publishedPoints: points)
    }

    private static func parseMatch(_ value: Any, page: OPGGPublicPage, platform: String) -> TrackedMatch? {
        guard let fields = page.object(value), let id = fields["id"] as? String,
              fields["region"] as? String == platform, let time = fields["playedAt"] as? Double, time > 0,
              let placement = (fields["displayPlacement"] ?? fields["placement"]) as? Int,
              (1...8).contains(placement) else { return nil }
        let units = (page.resolve(fields["units"]) as? [Any] ?? []).compactMap { value -> TrackedMatch.Unit? in
            guard let unit = page.object(value), let key = unit["key"] as? String else { return nil }
            let items = (page.resolve(unit["items"]) as? [Any] ?? []).compactMap { page.object($0)?["key"] as? String }
            return TrackedMatch.Unit(key: key, stars: unit["star"] as? Int, items: items, name: unit["name"] as? String)
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
                            playersEliminated: fields["playersEliminated"] as? Int, source: "OP.GG")
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
        let pattern = #"self\.__next_f\.push\((\[1,.*?)\)</script>"#
        let regex = try! NSRegularExpression(pattern: pattern)
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
            guard Int(key, radix: 16) != nil, payload.first == "[" || payload.first == "{",
                  let value = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) else { continue }
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
        let path = reference.dropFirst().split(separator: ":")
        guard depth < 8, let id = path.first, var result = rows[String(id)] else { return nil }
        for key in path.dropFirst() {
            if let object = result as? [String: Any], let next = object[String(key)] { result = next }
            else if let array = result as? [Any], let index = key == "props" ? 3 : Int(key), array.indices.contains(index) { result = array[index] }
            else { return nil }
        }
        return resolve(result, depth: depth + 1)
    }
}
