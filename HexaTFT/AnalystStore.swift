import Foundation
import Combine

struct TrainingGoal: Codable {
    let topic: TrainingTopic
    let startedAt: Date
    let set: Int
    let baseline: [TrackedMatch]
    func followUp(in matches: [TrackedMatch]) -> [TrackedMatch] {
        let baselineIDs = Set(baseline.map(\.id))
        return Array(MatchAnalyst(matches: matches, set: self.set, limit: Int.max).matches
            .filter { $0.timestamp > startedAt.timeIntervalSince1970 && !baselineIDs.contains($0.id) }
            .sorted { $0.timestamp < $1.timestamp }.prefix(10))
    }
}
struct AnalystMessage: Codable, Identifiable {
    var id = UUID()
    let question: String
    let answer: String
    let matchIDs: [String]
    let date: Date
    var context: String? = nil
    var evidence: [TrackedMatch]? = nil
}
@MainActor final class AnalystStore: ObservableObject {
    struct State: Codable {
        var goals: [String: TrainingGoal] = [:]
        var conversations: [String: [AnalystMessage]] = [:]
        var notes: [String: String] = [:]
    }
    @Published private(set) var state = State()
    @Published private(set) var error: String?
    private let file: URL
    init(directory: URL? = nil) {
        file = (directory ?? URL.applicationSupportDirectory.appendingPathComponent("HexaTFT")).appendingPathComponent("analyst-v1.json")
        if let raw = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(State.self, from: raw) { state = saved }
    }
    private func save(_ next: State) {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            state = next; error = nil
        } catch { self.error = "L’enregistrement local n’a pas abouti. Réessaie avant de quitter cet écran." }
    }
    func start(_ topic: TrainingTopic, account: String, report: MatchAnalyst) {
        guard let set = report.set else { return }
        var next = state; next.goals[account] = TrainingGoal(topic: topic, startedAt: .now, set: set, baseline: report.matches); save(next)
    }
    func stop(account: String) { var next = state; next.goals.removeValue(forKey: account); save(next) }
    func note(_ text: String, match: String, account: String) {
        var next = state; next.notes[account + ":" + match] = String(text.prefix(2000)); save(next)
    }
    func erase(account: String) {
        var next = state; next.goals.removeValue(forKey: account)
        next.notes = next.notes.filter { !$0.key.hasPrefix(account + ":") }
        next.conversations = next.conversations.filter { !$0.key.hasPrefix(account + ":") }; save(next)
    }
    func scope(account: String, report: MatchAnalyst) -> String { account + ":\(report.set ?? 0):" + (report.patch ?? "all") }
    func ask(_ question: String, account: String, report: MatchAnalyst) {
        let cleaned = String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !cleaned.isEmpty else { return }
        let response = Self.answer(cleaned, report: report)
        let key = scope(account: account, report: report)
        var next = state
        let evidence = Array(report.matches.filter { response.1.contains($0.id) }.prefix(30))
        next.conversations[key, default: []].append(AnalystMessage(question: cleaned, answer: response.0, matchIDs: evidence.map(\.id), date: .now,
            context: "Set \(report.set ?? 0) · \(report.matches.count) matchs · " + (report.patch ?? "tous patches"), evidence: evidence))
        next.conversations[key] = Array((next.conversations[key] ?? []).suffix(30)); save(next)
    }
    nonisolated static func answer(_ question: String, report: MatchAnalyst) -> (String, [String]) {
        let q = question.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
        guard !report.matches.isEmpty else { return ("Je n’ai pas de partie classée terminée dans cette sélection. Choisis un set déjà importé ou actualise le compte.", []) }
        if q.contains("en direct") || q.contains("maintenant sur mon plateau") {
            return ("Je travaille sur tes parties terminées. Pendant le jeu, consulte le parcours préparé dans Partie. Une analyse du timing demande une vidéo après le match.", [])
        }
        let topics: [TrainingTopic]
        if q.contains("objet") || q.contains("tank") || q.contains("equip") { topics = [.frontline, .stability] }
        else if q.contains("or ") || q.contains("economie") || q.contains("relanc") || q.contains("depens") { topics = [.economy] }
        else if q.contains("etoile") || q.contains("carry") || q.contains("porteur") { topics = [.stability] }
        else { topics = TrainingTopic.allCases }
        let findings = report.findings.filter { topics.contains($0.category) }
        if q.contains("compo") || q.contains("champion") || q.contains("reuss") {
            let groups = report.cohorts.prefix(4)
            let lines = groups.map { group in
                let s = AnalysisSummary(matches: group.matches)
                return "\(group.name) : \(s.top4)/\(s.count) top 4, moyenne \(String(format: "%.2f", s.average))."
            }
            return ((["Unités avec au moins deux objets complets dans ta sélection. Plusieurs peuvent appartenir au même match."] + lines + ["Ces petits groupes décrivent ton historique. Ils ne prédisent pas tes prochaines places et ne suffisent pas à choisir une composition à forcer."]).joined(separator: "\n\n"), Array(groups.flatMap { $0.matches.map(\.id) }))
        }
        let details = findings.prefix(3).map { $0.fact + "\n" + $0.interpretation + "\nÀ travailler : " + $0.exercise }
        let conclusion = "Limite : l’historique décrit le plateau final. Les boutiques, le banc, le timing des dépenses et le placement ne sont pas observés. Ouvre les matchs pour examiner les preuves."
        return (([report.overview] + details + [conclusion]).joined(separator: "\n\n"), Array(Set(findings.flatMap { $0.evidence.map(\.id) })).sorted())
    }
}
