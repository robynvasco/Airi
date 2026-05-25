import Foundation

public struct DatePhraseResolution: Equatable {
    public enum Status: Equatable {
        case resolved
        case ambiguous
        case unresolved
    }

    public var status: Status
    public var isoDate: String?
    public var message: String
}

public struct DatePhraseResolver {
    public var calendar: Calendar
    public var referenceDate: Date

    public init(calendar: Calendar, referenceDate: Date) {
        self.calendar = calendar
        self.referenceDate = referenceDate
    }

    public func resolve(_ phrase: String) -> DatePhraseResolution {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .unresolved("empty date phrase")
        }

        let normalized = trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("today") || normalized.contains("heute") {
            return resolved(referenceDate)
        }

        if normalized.contains("day after tomorrow")
            || normalized.contains("ubermorgen")
            || normalized.contains("uebermorgen") {
            return resolved(calendar.date(byAdding: .day, value: 2, to: referenceDate))
        }

        if normalized.contains("tomorrow") || normalized.contains("morgen") {
            return resolved(calendar.date(byAdding: .day, value: 1, to: referenceDate))
        }

        if let explicitDate = resolveExplicitDayMonth(normalized) {
            return explicitDate
        }

        if let weekday = weekday(in: normalized) {
            if normalized.contains("ubernachste woche")
                || normalized.contains("uebernaechste woche")
                || normalized.contains("week after next") {
                return resolved(dateInWeek(offset: 2, weekday: weekday))
            }

            if normalized.contains("nachste woche") || normalized.contains("next week") {
                return resolved(dateInWeek(offset: 1, weekday: weekday))
            }

            return resolved(nextDate(matchingWeekday: weekday))
        }

        return .unresolved("date phrase is not supported yet")
    }

    public func resolveToISODate(_ phrase: String) -> String? {
        let resolution = resolve(phrase)
        guard resolution.status == .resolved else {
            return nil
        }

        return resolution.isoDate
    }

    private func resolveExplicitDayMonth(_ normalized: String) -> DatePhraseResolution? {
        let monthAlternatives = monthNames
            .flatMap { month, names in names.map { ($0, month) } }
            .sorted { $0.0.count > $1.0.count }

        for (name, month) in monthAlternatives where normalized.contains(name) {
            guard let day = firstNumber(in: normalized) else {
                return nil
            }

            return explicitDate(day: day, month: month, year: explicitYear(in: normalized))
        }

        let numericPattern = #"(?<!\d)(\d{1,2})\s*[.\/]\s*(\d{1,2})(?:\s*[.\/]\s*(\d{2,4}))?(?!\d)"#
        guard
            let regex = try? NSRegularExpression(pattern: numericPattern),
            let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
            let dayRange = Range(match.range(at: 1), in: normalized),
            let monthRange = Range(match.range(at: 2), in: normalized),
            let day = Int(normalized[dayRange]),
            let month = Int(normalized[monthRange])
        else {
            return nil
        }

        var year: Int?
        if match.range(at: 3).location != NSNotFound,
           let yearRange = Range(match.range(at: 3), in: normalized),
           let parsedYear = Int(normalized[yearRange]) {
            year = parsedYear < 100 ? 2000 + parsedYear : parsedYear
        }

        return explicitDate(day: day, month: month, year: year)
    }

    private func explicitDate(day: Int, month: Int, year: Int?) -> DatePhraseResolution {
        let referenceYear = calendar.component(.year, from: referenceDate)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year ?? referenceYear
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day,
              calendar.component(.month, from: date) == month else {
            return .unresolved("invalid calendar date")
        }

        if year == nil && isBeforeStartOfReferenceDay(date) {
            return .ambiguous("date is in the past and no year was given")
        }

        return resolved(date)
    }

    private func firstNumber(in text: String) -> Int? {
        guard
            let regex = try? NSRegularExpression(pattern: #"(?<!\d)(\d{1,2})(?!\d)"#),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return Int(text[range])
    }

    private func explicitYear(in text: String) -> Int? {
        guard
            let regex = try? NSRegularExpression(pattern: #"(?<!\d)(20\d{2}|19\d{2})(?!\d)"#),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return Int(text[range])
    }

    private func dateInWeek(offset: Int, weekday: Int) -> Date? {
        let startOfReferenceWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
        let startOfTargetWeek = startOfReferenceWeek.flatMap {
            calendar.date(byAdding: .weekOfYear, value: offset, to: $0)
        }

        guard let startOfTargetWeek else {
            return nil
        }

        return calendar.nextDate(
            after: calendar.date(byAdding: .day, value: -1, to: startOfTargetWeek) ?? startOfTargetWeek,
            matching: DateComponents(weekday: weekday),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func nextDate(matchingWeekday weekday: Int) -> Date? {
        var components = DateComponents()
        components.weekday = weekday

        return calendar.nextDate(
            after: referenceDate,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func resolved(_ date: Date?) -> DatePhraseResolution {
        guard let date, let isoDate = iso(date) else {
            return .unresolved("date could not be calculated")
        }

        return DatePhraseResolution(status: .resolved, isoDate: isoDate, message: "resolved")
    }

    private func isBeforeStartOfReferenceDay(_ date: Date) -> Bool {
        date < calendar.startOfDay(for: referenceDate)
    }

    private func iso(_ date: Date?) -> String? {
        guard let date else {
            return nil
        }

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return nil
        }

        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func weekday(in normalized: String) -> Int? {
        for (weekday, names) in weekdayNames where names.contains(where: { normalized.contains($0) }) {
            return weekday
        }

        return nil
    }

    private var weekdayNames: [(weekday: Int, names: [String])] {
        [
            (2, ["monday", "montag"]),
            (3, ["tuesday", "dienstag"]),
            (4, ["wednesday", "mittwoch"]),
            (5, ["thursday", "donnerstag"]),
            (6, ["friday", "freitag"]),
            (7, ["saturday", "samstag", "sonnabend"]),
            (1, ["sunday", "sonntag"])
        ]
    }

    private var monthNames: [Int: [String]] {
        [
            1: ["january", "januar", "jan"],
            2: ["february", "februar", "feb"],
            3: ["march", "marz", "maerz", "mar"],
            4: ["april", "apr"],
            5: ["may", "mai"],
            6: ["june", "juni", "jun"],
            7: ["july", "juli", "jul"],
            8: ["august", "aug"],
            9: ["september", "sep"],
            10: ["october", "oktober", "oct", "okt"],
            11: ["november", "nov"],
            12: ["december", "dezember", "dec", "dez"]
        ]
    }
}

private extension DatePhraseResolution {
    static func ambiguous(_ message: String) -> DatePhraseResolution {
        DatePhraseResolution(status: .ambiguous, isoDate: nil, message: message)
    }

    static func unresolved(_ message: String) -> DatePhraseResolution {
        DatePhraseResolution(status: .unresolved, isoDate: nil, message: message)
    }
}
