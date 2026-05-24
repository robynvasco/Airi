import Foundation

enum PeopleExtractor {
    static func explicitPeople(in task: InputTask) -> [String] {
        let words = task.text
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map(String.init)

        var people: [String] = []

        for index in words.indices {
            let marker = words[index].folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
            guard marker == "mit" || marker == "with" else {
                continue
            }

            let nextIndex = words.index(after: index)
            guard nextIndex < words.endIndex else {
                continue
            }

            let candidate = words[nextIndex].trimmingCharacters(in: .punctuationCharacters)
            if !candidate.isEmpty {
                people.append(candidate)
            }
        }

        return people
    }
}

