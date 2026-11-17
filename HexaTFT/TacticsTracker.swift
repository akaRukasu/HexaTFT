import Foundation

enum TrackerProfileSources {
    typealias Loader = (RiotIdentity) async throws -> RiotProfile

    static func fetch(_ identity: RiotIdentity, preferred: String? = nil,
                      opgg: Loader = OPGGTracker.fetch, tactics: Loader = TacticsTracker.fetch) async throws -> RiotProfile {
        let useTacticsFirst = preferred == TacticsTracker.source
        let first = useTacticsFirst ? tactics : opgg
        let second = useTacticsFirst ? opgg : tactics
        do {
            return try await first(identity)
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            do {
                return try await second(identity)
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                throw DataIssue.invalid("OP.GG et Tactics.Tools n’ont pas fourni de fiche exploitable pour \(identity.riotID) sur \(identity.regionName). Réessaie ou ouvre la fiche publique pour vérifier sa disponibilité.")
            }
        }
    }
}

enum TacticsTracker {
    static let source = "Tactics.Tools"
    private static let reference: [String: ReferenceEntry] = {
        guard let url = Bundle.main.url(forResource: "live-reference", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalogue = try? JSONDecoder().decode(ReferenceData.self, from: data) else { return [:] }
        return Dictionary(catalogue.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    static func fetch(_ identity: RiotIdentity) async throws -> RiotProfile {
        #if DEBUG
        if let html = ProcessInfo.processInfo.environment["HEXA_TACTICS_TRACKER_FIXTURE"] {
            return try parse(html, identity: identity)
        }
        #endif
        guard let url = identity.publicProfile else { throw DataIssue.invalid("Serveur indisponible sur Tactics.Tools.") }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 14)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.httpShouldHandleCookies = false
        let (body, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url?.scheme == "https", ["tactics.tools", "www.tactics.tools"].contains(http.url?.host ?? ""),
              body.count <= 4_000_000, let html = String(data: body, encoding: .utf8) else {
            throw DataIssue.invalid("La fiche publique Tactics.Tools est indisponible.")
        }
        return try await Task.detached(priority: .utility) { try parse(html, identity: identity) }.value
    }

    static func parse(_ html: String, identity: RiotIdentity, checkedAt: Date = .now) throws -> RiotProfile {
        let pattern = #"<script\b[^>]*\bid\s*=\s*["']__NEXT_DATA__["'][^>]*>(.*?)</script\s*>"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive])
        guard let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html),
              let root = try JSONSerialization.jsonObject(with: Data(html[range].utf8)) as? [String: Any],
              let props = root["props"] as? [String: Any], let page = props["pageProps"] as? [String: Any],
              let data = page["initialData"] as? [String: Any], let player = data["playerInfo"] as? [String: Any],
              let name = player["name"] as? String, let tag = player["tag"] as? String,
              (name + "#" + tag).caseInsensitiveCompare(identity.riotID) == .orderedSame,
              let region = player["region"] as? String,
              RiotIdentity.regions.contains(where: { $0.0 == identity.region && [$0.0, $0.2].contains(region.lowercased()) }),
              let rows = data["matches"] as? [[String: Any]] else {
            throw DataIssue.invalid("La fiche Tactics.Tools ne contient pas les données du compte demandé.")
        }

        let matches = rows.compactMap { parseMatch($0, identity: identity) }.sorted { $0.timestamp > $1.timestamp }
        guard rows.isEmpty || !matches.isEmpty else { throw DataIssue.invalid("L’historique Tactics.Tools est illisible.") }
        let seasons = (player["setsRanks"] as? [[String: Any]] ?? []).compactMap { row -> (Int, [RankPoint])? in
            guard let setCode = row["set"] as? Int, (10...999).contains(setCode) else { return nil }
            let solo = rankPoint(row["ranked"] as? [Any], queue: "RANKED_TFT")
            let duo = rankPoint(row["duo"] as? [Any], queue: "RANKED_TFT_DOUBLE_UP")
            return (setCode, [solo, duo].compactMap { $0 })
        }.sorted { $0.0 > $1.0 }
        let current = seasons.first
        let soloStats = (data["queueSeasonStats"] as? [String: [String: Any]])?["1100"]
        let indexedGames = soloStats?["games"] as? Int
        var ranks = current?.1.map(\.rank) ?? []
        if let league = player["rankedLeague"] as? [Any], league.count >= 2,
           let tier = league[0] as? String, let lp = league[1] as? Int,
           var solo = rank(tier, lp: lp, queue: "RANKED_TFT", games: ranks.first { $0.queue == "RANKED_TFT" }?.games) {
            if let local = player["localRank"] as? [Any], let position = local.first as? Int { solo.rankPosition = position }
            if let count = indexedGames, count == solo.games, let rate = soloStats?["top4"] as? Double, (0...1).contains(rate) {
                solo.top4Count = Int((rate * Double(count)).rounded())
            }
            ranks.removeAll { $0.queue == "RANKED_TFT" }
            ranks.insert(solo, at: 0)
        }
        let history = (data["rankHistory"] as? [[Any]] ?? []).compactMap { rankPoint($0, queue: "RANKED_TFT") }
        let duoHistory = (data["duoRankHistory"] as? [[Any]] ?? []).compactMap { rankPoint($0, queue: "RANKED_TFT_DOUBLE_UP") }
        let observedAt = current?.1.first(where: { $0.rank.queue == "RANKED_TFT" })?.date.timeIntervalSince1970
            ?? history.first?.date.timeIntervalSince1970 ?? matches.first?.timestamp ?? checkedAt.timeIntervalSince1970
        let older = seasons.dropFirst().compactMap { code, points -> SeasonRecord? in
            guard !points.isEmpty else { return nil }
            let suffix = code % 10
            let number = suffix == 0 ? String(code / 10) : "\(code / 10).\(suffix)"
            return SeasonRecord(id: "TFTSet" + number, number: number, ranks: points.map(\.rank))
        }
        return RiotProfile(id: identity.trackerID, riotID: name + "#" + tag, region: identity.region,
                           observedAt: observedAt, matches: matches, ranks: ranks, source: source,
                           checkedAt: checkedAt, publishedPoints: history + duoHistory, seasons: older,
                           currentSet: current.map { $0.0 / 10 }, indexedGames: indexedGames)
    }

    private static func rankPoint(_ row: [Any]?, queue: String) -> RankPoint? {
        guard let row, row.count >= 4, let time = row[0] as? Double, time.isFinite, time > 0,
              let tier = row[1] as? String, let lp = row[2] as? Int,
              let rank = rank(tier, lp: lp, queue: queue, games: row[3] as? Int) else { return nil }
        return RankPoint(date: Date(timeIntervalSince1970: time), rank: rank)
    }

    private static func rank(_ label: String, lp: Int, queue: String, games: Int?) -> RiotProfile.Rank? {
        let words = label.split(separator: " ", maxSplits: 1).map(String.init)
        guard let tier = words.first, ["IRON", "BRONZE", "SILVER", "GOLD", "PLATINUM", "EMERALD", "DIAMOND", "MASTER", "GRANDMASTER", "CHALLENGER"].contains(tier), lp >= 0 else { return nil }
        return RiotProfile.Rank(queue: queue, tier: tier, division: words.dropFirst().first ?? "", lp: lp,
                                wins: nil, losses: nil, games: games)
    }

    private static func parseMatch(_ row: [String: Any], identity: RiotIdentity) -> TrackedMatch? {
        guard let id = row["id"] as? String, id.uppercased().hasPrefix(identity.region.uppercased() + "_"),
              let ms = row["dateTime"] as? Double, ms.isFinite, ms > 1_000_000_000_000,
              let queue = row["queueId"] as? Int, let info = row["info"] as? [String: Any],
              let name = info["name"] as? String, let tag = info["tag"] as? String,
              (name + "#" + tag).caseInsensitiveCompare(identity.riotID) == .orderedSame,
              let placement = info["placement"] as? Int, (1...(queue == 1160 ? 4 : 8)).contains(placement) else { return nil }
        let patchCode = row["patch"] as? Int
        let branch = patchCode.map { "\($0 / 1000).\(($0 / 10) % 100)" }
        let roster = info["units"] as? [[String: Any]] ?? []
        let set = matchSet(branch: branch, roster: roster)
        let patch = branch.flatMap { MetaStore.patchNumber(for: $0, set: set.map(String.init)) } ?? branch
        let units = roster.compactMap { unit -> TrackedMatch.Unit? in
            guard let key = unit["id"] as? String else { return nil }
            let entry = reference["champion:" + key]
            let itemKeys = unit["items2"] as? [String]
            let legacyItems = unit["items"] as? [Int] ?? []
            let equipment = (legacyItems.isEmpty || itemKeys?.isEmpty == false) ? itemKeys?.map(matchItem) : nil
            return TrackedMatch.Unit(key: key, stars: unit["tier"] as? Int,
                                     items: equipment?.map(\.key) ?? legacyItems.map { "Objet #\($0)" },
                                     name: entry?.name, equipment: equipment, cost: entry?.cost,
                                     range: entry?.balance?["range"], imageURL: entry?.imageURL)
        }
        return TrackedMatch(id: id, timestamp: ms / 1000, patch: patch, set: set,
                            queue: queue, mode: nil, placement: placement, level: info["level"] as? Int,
                            units: units, traits: [], augments: [], lobby: [], duration: row["duration"] as? Double,
                            lastRound: info["lastRound"] as? Int, source: source, augmentsKnown: false)
    }

    private static func matchSet(branch: String?, roster: [[String: Any]]) -> Int? {
        if let branch, MetaStore.patchNumber(for: branch, set: "18") != nil { return 18 }
        let numbers = Set(roster.compactMap { unit -> Int? in
            guard let key = unit["id"] as? String else { return nil }
            let prefix = key.hasPrefix("DA_") ? "DA_" : "TFT"
            guard key.hasPrefix(prefix) else { return nil }
            return Int(key.dropFirst(prefix.count).prefix(while: \.isNumber))
        })
        return numbers.count == 1 ? numbers.first : nil
    }

    private static func matchItem(_ key: String) -> MatchItem {
        let entry = reference["item:" + key]
        let tags = entry?.itemTags ?? []
        let category: String?
        if tags.contains("component") || key.hasPrefix("DA_Component_") || MatchItem.componentKeys.contains(key) {
            category = "component"
        } else if entry?.components?.count == 2 || tags.contains("{7ea41d13}") {
            category = "standard"
        } else if tags.contains("{6ef5c598}") {
            category = "radiant"
        } else {
            category = nil
        }
        return MatchItem(key: key, name: entry?.name ?? key, category: category, imageURL: entry?.imageURL,
                         components: entry?.components?.compactMap { reference["item:" + $0]?.name }, effect: entry?.effectText)
    }
}
