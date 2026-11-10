import Foundation

struct CompeteSchedule: Codable {
    let checked: Date
    let entries: [Entry]
    static let paris = TimeZone(identifier: "Europe/Paris")!
    static var source: URL { URL(string: "https://riot.com/S18CompeteCalendar")! }
    private static let feed = URL(string: "https://calendar.google.com/calendar/ical/c_ccdd5bddb8439991873f9f2d1cfd9c0184b6fb0007bd3e2fba68857bc7659dd8%40group.calendar.google.com/public/basic.ics")!

    struct Entry: Codable, Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let allDay: Bool

        var isMilestone: Bool {
            ["snapshot", "sign-up", "registration", " live"].contains { title.localizedCaseInsensitiveContains($0) }
        }
        var displayTitle: String {
            title.replacingOccurrences(of: "Regional Finals", with: "Finales régionales")
                .replacingOccurrences(of: "Week ", with: "semaine ")
                .replacingOccurrences(of: "Weekly Ladder Snapshot", with: "Relevé hebdomadaire du ladder")
                .replacingOccurrences(of: "Sign-ups open", with: "ouverture des inscriptions", options: .caseInsensitive)
                .replacingOccurrences(of: "Sign-ups close", with: "fin des inscriptions", options: .caseInsensitive)
                .replacingOccurrences(of: "Ladder Snapshot", with: "relevé du ladder", options: .caseInsensitive)
        }
        var displayDate: String {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = CompeteSchedule.paris
            let last = allDay ? calendar.date(byAdding: .day, value: -1, to: end) ?? end : end
            let style = Date.FormatStyle(date: .abbreviated, time: allDay ? .omitted : .shortened,
                                         locale: Locale(identifier: "fr_FR"), timeZone: CompeteSchedule.paris)
            if allDay ? calendar.isDate(start, inSameDayAs: last) : start == last { return start.formatted(style) }
            return start.formatted(style) + " → " + last.formatted(style)
        }
    }

    static func fetch() async -> Self? {
        guard let data = try? await DragonFeed.get(feed, max: 500_000),
              let calendar = String(data: data, encoding: .utf8) else { return nil }
        let entries = parse(calendar)
        return entries.isEmpty ? nil : Self(checked: .now, entries: entries)
    }

    static func parse(_ ics: String) -> [Entry] {
        let calendar = ics.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n ", with: "").replacingOccurrences(of: "\n\t", with: "")
        guard calendar.hasPrefix("BEGIN:VCALENDAR\n"), calendar.contains("\nEND:VCALENDAR") else { return [] }
        var seen = Set<String>()
        return calendar.components(separatedBy: "BEGIN:VEVENT\n").dropFirst().compactMap { event -> Entry? in
            guard let endMarker = event.range(of: "\nEND:VEVENT") else { return nil }
            var values: [String: (String, String)] = [:]
            for line in event[..<endMarker.lowerBound].split(separator: "\n") {
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2, let key = parts[0].split(separator: ";").first else { continue }
                values[String(key)] = (String(parts[0]), String(parts[1]))
            }
            guard values["STATUS"]?.1 != "CANCELLED", let id = values["UID"]?.1,
                  let summary = values["SUMMARY"]?.1, let (startField, startValue) = values["DTSTART"],
                  let (start, allDay) = date(startValue, field: startField) else { return nil }
            let title = summary.replacingOccurrences(of: #"\"#, with: "").trimmingCharacters(in: .whitespaces)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = paris
            let defaultEnd = allDay ? calendar.date(byAdding: .day, value: 1, to: start) ?? start : start
            let end = values["DTEND"].flatMap { date($0.1, field: $0.0)?.0 } ?? defaultEnd
            guard !title.isEmpty, end >= start, !allDay || end > start, seen.insert(id).inserted else { return nil }
            return Entry(id: id, title: title, start: start, end: end, allDay: allDay)
        }.sorted { ($0.start, $0.title, $0.id) < ($1.start, $1.title, $1.id) }
    }

    private static func date(_ value: String, field: String) -> (Date, Bool)? {
        let allDay = field.contains("VALUE=DATE") && !field.contains("VALUE=DATE-TIME")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        if allDay {
            formatter.timeZone = paris
            formatter.dateFormat = "yyyyMMdd"
        } else if value.hasSuffix("Z") {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        } else if let tz = field.components(separatedBy: "TZID=").last, tz != field,
                  let zone = TimeZone(identifier: String(tz.prefix { $0 != ";" })) {
            formatter.timeZone = zone
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        } else {
            return nil
        }
        return formatter.date(from: value).map { ($0, allDay) }
    }
}
