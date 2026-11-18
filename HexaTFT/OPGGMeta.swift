import Foundation

struct OPGGMetaSnapshot: Codable {
    static let source = URL(string: "https://op.gg/tft/meta-trends/comps")!
    struct Audience: Codable, Hashable {
        let region: String
        let tier: String
        static let global = Self(region: "global", tier: "PLATINUM+")

        init(region: String, tier: String) {
            self.region = region
            self.tier = tier
        }

        init?(identity: RiotIdentity, profile: RiotProfile) {
            guard let region = identity.opggProfile?.pathComponents.dropLast().last,
                  let tier = profile.ranks.first(where: { $0.queue == "RANKED_TFT" })?.tier,
                  Self.labels[tier] != nil else { return nil }
            self.init(region: region, tier: tier)
        }

        private static let labels = ["IRON": "Fer", "BRONZE": "Bronze", "SILVER": "Argent", "GOLD": "Or",
                                     "PLATINUM": "Platine", "EMERALD": "Émeraude", "DIAMOND": "Diamant",
                                     "MASTER": "Maître", "GRANDMASTER": "Grand maître", "CHALLENGER": "Challenger",
                                     "PLATINUM+": "Platine+"]
        var label: String { "\(region == "global" ? "Toutes régions" : region.uppercased()) · \(Self.labels[tier] ?? tier)" }

        var url: URL {
            guard self != .global, var components = URLComponents(url: OPGGMetaSnapshot.source, resolvingAgainstBaseURL: false) else {
                return OPGGMetaSnapshot.source
            }
            components.queryItems = [URLQueryItem(name: "region", value: region), URLQueryItem(name: "tier", value: tier)]
            return components.url ?? OPGGMetaSnapshot.source
        }
    }
    let pack: MetaPack
    let build: String
    let publishedAt: Date
    let scope: String
    var audience: Audience? = nil

    static func fetch(audience: Audience) async -> Page? {
        #if DEBUG
        if let html = ProcessInfo.processInfo.environment["HEXA_OPGG_META_FIXTURE"] { return Page(html) }
        if ProcessInfo.processInfo.environment["HEXA_META_OFFLINE_TEST"] == "1" { return nil }
        #endif
        guard let data = try? await DragonFeed.get(audience.url, max: 8_000_000),
              let html = String(data: data, encoding: .utf8) else { return nil }
        return await Task.detached(priority: .utility) { Page(html) }.value
    }

    struct Page {
        private let page: OPGGPublicPage
        private let data: [String: Any]
        init?(_ html: String) {
            let page = OPGGPublicPage(html)
            guard let data = page.payload(containing: ["generation", "metadata", "comps", "filters"]),
                  data["status"] as? String == "ready" else { return nil }
            self.page = page
            self.data = data
        }

        var publishedPatch: String? { page.object(data["generation"])?["patch"] as? String }
        var setNumber: String? { (page.object(data["generation"])?["set"] as? Int).map(String.init) }
        var isAnalyzing: Bool { page.object(data["metadata"])?["newPatchAnalyzing"] as? Bool == true }

        // OP.GG supplies a patch-specific roster as well as statistics. This can
        // complete the live catalogue while CommunityDragon publishes its build.
        func reference(branch: String, patch: String) -> ReferenceData? {
            guard publishedPatch == patch, let set = setNumber,
                  MetaStore.patchNumber(for: branch, set: set) == patch,
                  let metadata = page.object(data["metadata"]),
                  metadata["currentPatch"] as? String == patch, !isAnalyzing,
                  let timestamp = metadata["updatedAt"] as? String,
                  let date = OPGGTracker.timestampDate(timestamp), date <= .now.addingTimeInterval(300) else { return nil }
            var entries: [String: ReferenceEntry] = [:]
            for (field, kind) in [("champions", "champion"), ("items", "item"), ("traits", "trait")] {
                for value in page.resolve(data[field]) as? [Any] ?? [] {
                    guard let row = page.object(value), let key = row["key"] as? String,
                          let name = row["name"] as? String, !key.isEmpty, !name.isEmpty else { continue }
                    let ability = page.object(row["ability"])
                    let detail = (page.resolve(ability?["description"] ?? row["description"]) as? String ?? "")
                        .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    let components = (page.resolve(row["componentItems"]) as? [Any])?.compactMap { page.object($0)?["key"] as? String }
                    let traits = (page.resolve(row["traits"]) as? [Any])?.compactMap { page.object($0)?["name"] as? String }
                    let stats = page.object(row["combatStats"])?.compactMapValues { $0 as? Double }
                    let id = kind + ":" + key
                    entries[id] = ReferenceEntry(id: id, name: name, kind: kind, set: set, cost: row["cost"] as? Int ?? 0,
                        description: detail, imageURL: row["imageUrl"] as? String ?? "", components: components,
                        itemTags: (row["category"] as? String).map { [$0] }, balance: stats, traitNames: traits)
                }
            }
            guard entries.values.contains(where: { $0.kind == "champion" }),
                  entries.values.contains(where: { $0.kind == "item" }) else { return nil }
            return ReferenceData(version: branch + ".opgg", source: OPGGMetaSnapshot.source.absoluteString,
                                 retrievedAt: timestamp, entries: entries.values.sorted { $0.id < $1.id })
        }

        func snapshot(reference: ReferenceData, branch: String, patch: String?, audience: Audience = .global) -> OPGGMetaSnapshot? {
            guard let generation = page.object(data["generation"]),
                  let set = generation["set"] as? Int, reference.entries.first?.set == String(set),
                  let version = generation["patch"] as? String, version.range(of: #"^\d{1,2}\.\d{1,2}$"#, options: .regularExpression) != nil,
                  patch == nil || patch == version,
                  reference.version.hasPrefix(branch + "."),
                  let metadata = page.object(data["metadata"]),
                  metadata["currentPatch"] as? String == version,
                  metadata["newPatchAnalyzing"] as? Bool != true,
                  metadata["sliceApplied"] as? Bool == true,
                  let timestamp = metadata["updatedAt"] as? String,
                  let date = OPGGTracker.timestampDate(timestamp), date <= .now.addingTimeInterval(300),
                  let filters = page.object(data["filters"]),
                  let rank = filters["tier"] as? String, let region = filters["region"] as? String,
                  rank == audience.tier, region == audience.region,
                  let hours = filters["window"] as? Int, hours > 0,
                  let rows = page.resolve(data["comps"]) as? [Any] else { return nil }
            let ids = Set(reference.entries.map(\.id))
            let champs = Set(reference.entries.filter { $0.kind == "champion" }.map { String($0.id.dropFirst(9)) })
            let comps = rows.compactMap { comp($0, build: branch, audience: audience, ids: ids, champions: champs) }
            guard !comps.isEmpty, Set(comps.map(\.id)).count == comps.count else { return nil }
            return OPGGMetaSnapshot(pack: MetaPack(data: comps, retrievedAt: timestamp, set: String(set), patch: version),
                                    build: branch, publishedAt: date,
                                    scope: "\(audience.label) · \(hours) h", audience: audience)
        }

        private func comp(_ value: Any, build: String, audience: Audience,
                          ids: Set<String>, champions: Set<String>) -> MetaComp? {
            guard let row = page.object(value), let id = row["id"] as? String,
                  id.range(of: #"^[a-zA-Z0-9_-]{1,140}$"#, options: .regularExpression) != nil,
                  let name = row["name"] as? String, (1...120).contains(name.count),
                  let stats = page.object(row["stats"]), let average = stats["avgPlacement"] as? Double,
                  let win = stats["winRate"] as? Double, let top = stats["top4Rate"] as? Double,
                  let count = stats["count"] as? Int, let pick = stats["pickRate"] as? Double,
                  count > 0, (1...8).contains(average), (0...1).contains(top), (0...top).contains(win), (0...1).contains(pick),
                  let roster = page.resolve(row["units"]) as? [Any], (1...28).contains(roster.count) else { return nil }
            let resolved = roster.compactMap { page.object($0) }
            let units = resolved.compactMap { unit -> MetaUnit? in
                guard let key = unit["key"] as? String, champions.contains(key) else { return nil }
                let rawItems = page.resolve(unit["items"]) as? [Any] ?? []
                let items = rawItems.compactMap { page.object($0)?["key"] as? String }
                guard items.count == rawItems.count, items.allSatisfy({ ids.contains("item:" + $0) }) else { return nil }
                return MetaUnit(name: key, items: items, star_level: unit["observedStar"] as? Double)
            }
            guard units.count == roster.count, Set(units.map(\.name)).count == units.count else { return nil }
            let carries = resolved.filter { $0["role"] as? String == "carry" }.compactMap { $0["key"] as? String }
            let front = resolved.first { $0["role"] as? String == "tank" }?["key"] as? String
            let requirements = (page.resolve(row["requirementBadges"]) as? [Any] ?? []).compactMap { page.object($0)?["name"] as? String }
            let level = row["strategyLevel"] as? Int
            let reroll = row["isReroll"] as? Bool == true
            let type = level.map { reroll ? "roll_\($0)" : "fast_\($0)" }
            let tier = ["OP": 1, "S": 1, "A": 2, "B": 3, "C": 4, "D": 5][stats["tier"] as? String ?? ""] ?? 0
            let metrics = MetaStats(avg_placement: average, nb_games: count, pick_rate: pick,
                                    top_1_percent: win, top_4_percent: top, tier: tier)
            return MetaComp(comp_id: id, slug: id, stats: metrics, units: units, units_positions: nil,
                            carry_units: carries, traits: nil,
                            strategy: MetaStrategy(type: type, level_stage: nil), variations: nil, augments: nil,
                            carry_item_holders: nil, units_stats: nil, carousel_priority: nil, play_conditions: nil,
                            display_patch: build, rank: audience.tier, region: audience.region, sourceURL: audience.url,
                            publishedPlan: PublishedMetaPlan(name: name, difficulty: row["difficulty"] as? Int,
                                                            targetLevel: level, requirements: requirements,
                                                            primaryUnit: carries.first, frontline: front,
                                                            smallSample: stats["smallSample"] as? Bool == true))
        }
    }
}

extension MetaComp {
    func suggestedPublicBoard(reference: ReferenceData?) -> GuideBoard? {
        guard let plan = publishedPlan, let reference, !units.isEmpty else { return nil }
        return GuideBoard(units: units, positions: Self.suggestedPositions(units: units, frontline: plan.frontline, reference: reference),
                          sourceLabel: "Unités OP.GG · placement indicatif Hexa", sample: nil, isFinal: true)
    }

    static func suggestedPositions(units: [MetaUnit], frontline: String?, reference: ReferenceData) -> [MetaPosition] {
        let front = [3, 2, 4, 1, 5, 0, 6, 10, 9, 11, 8, 12, 7, 13]
        let back = [24, 22, 26, 23, 25, 21, 27, 17, 16, 18, 15, 19, 14, 20]
        let ordered = units.sorted {
            if $0.name == $1.name { return false }
            if $0.name == frontline { return true }
            if $1.name == frontline { return false }
            return $0.name < $1.name
        }
        var occupied: Set<Int> = []
        return ordered.compactMap { unit in
            let range = reference.champion(key: unit.name)?.balance?["range"] ?? 1
            let preferred: [Int]
            if unit.name == frontline || range <= 1 { preferred = front + back.reversed() }
            else if range <= 2 { preferred = [10, 9, 11, 8, 12, 7, 13] + front + back }
            else { preferred = back + front.reversed() }
            guard let cell = preferred.first(where: { !occupied.contains($0) }) else { return nil }
            occupied.insert(cell)
            return MetaPosition(board_position: cell, unit_api_name: unit.name)
        }
    }
}
