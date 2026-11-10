import Foundation

enum DragonFeed {
    struct Build: Decodable {
        let version: String
        var revision: String { String(version.prefix { $0 != "+" }) }
    }
    struct Payload: Decodable {
        let items: [Item]
        let setData: [SetData]
    }
    struct SetData: Decodable {
        let number: Int
        let mutator: String
        let champions: [Champion]
        let traits: [Trait]
        let items: [String]
        let augments: [String]
    }
    struct Champion: Decodable {
        let apiName: String?
        let name: String?
        let cost: Int?
        let icon: String?
        let squareIcon: String?
        let ability: Ability?
    }
    struct Ability: Decodable { let desc: String? }
    struct Trait: Decodable { let apiName: String?; let name: String?; let desc: String?; let icon: String? }
    struct Item: Decodable {
        let apiName: String?
        let name: String?
        let icon: String?
        let desc: String?
        let tags: [String]?
        let composition: [String]?
    }
    struct EUW: Decodable { let v: String }
    static func get(_ url: URL, max: Int, session: URLSession = .shared) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 35)
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= max else {
            throw DataIssue.invalid("Réponse du fournisseur indisponible ou trop volumineuse.")
        }
        return data
    }
    static func build(at branch: String) async throws -> String {
        let url = URL(string: "https://raw.communitydragon.org/\(branch)/content-metadata.json")!
        return try await JSONDecoder().decode(Build.self, from: get(url, max: 10_000)).revision
    }
    static func liveEUW() async throws -> String {
        let url = URL(string: "https://ddragon.leagueoflegends.com/realms/euw.json")!
        return try await JSONDecoder().decode(EUW.self, from: get(url, max: 10_000)).v
    }
    static func reference(branch: String, revision: String, set requestedSet: String?) async throws -> ReferenceData {
        let url = URL(string: "https://raw.communitydragon.org/\(branch)/cdragon/tft/fr_fr.json")!
        let data = try await get(url, max: 55_000_000)
        return try await Task.detached(priority: .utility) {
            try decodeReference(data, branch: branch, revision: revision, set: requestedSet, source: url.absoluteString)
        }.value
    }
    static func decodeReference(_ data: Data, branch: String, revision: String, set requestedSet: String?, source: String) throws -> ReferenceData {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let standard = payload.setData.filter { $0.mutator == "TFTSet" + String($0.number) && !$0.champions.isEmpty }
        guard let set = standard.filter({ requestedSet == nil || String($0.number) == requestedSet }).max(by: { $0.number < $1.number }) else {
            throw DataIssue.invalid("Le set de cet export est indisponible.")
        }
        var entries: [String: ReferenceEntry] = [:]
        func add(_ kind: String, _ key: String?, _ name: String?, _ art: String?, _ description: String?,
                 cost: Int = 0, components: [String]? = nil, tags: [String]? = nil) {
            guard let key, !key.isEmpty, let name, !name.isEmpty else { return }
            let id = kind + ":" + key
            let cleaned = (description ?? "").replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: #"%i:[^%]+%|<[^>]+>"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&")
            var path = art?.lowercased() ?? ""
            if path.hasSuffix(".tex") { path = String(path.dropLast(4)) + ".png" }
            let imageURL = path.hasPrefix("assets/") ? "https://raw.communitydragon.org/\(branch)/game/" + path : ""
            let suffix = kind == "champion" && (key.hasSuffix("_AP") || key.hasSuffix("_AD")) ? " (\(key.suffix(2)))" : ""
            entries[id] = ReferenceEntry(id: id, name: name + suffix, kind: kind, set: String(set.number),
                                        cost: cost, description: cleaned, imageURL: imageURL, components: components, itemTags: tags)
        }
        for c in set.champions { add("champion", c.apiName, c.name, c.squareIcon ?? c.icon, c.ability?.desc, cost: c.cost ?? 0) }
        for t in set.traits { add("trait", t.apiName, t.name, t.icon, t.desc) }
        let items = Dictionary(payload.items.compactMap { item in item.apiName.map { ($0, item) } }, uniquingKeysWith: { first, _ in first })
        for key in Set(set.items) {
            if let i = items[key] { add("item", key, i.name, i.icon, i.desc, components: i.composition, tags: i.tags) }
        }
        for key in Set(set.augments) {
            if let i = items[key] { add("augment", key, i.name, i.icon, i.desc, tags: i.tags) }
        }
        guard entries.count > 40 else { throw DataIssue.invalid("Export du Codex incomplet.") }
        return ReferenceData(version: revision, source: source, retrievedAt: Date().ISO8601Format(), entries: entries.values.sorted { $0.id < $1.id })
    }
}
