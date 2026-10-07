import Foundation
import Observation

struct Todo: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var notes = ""
    var created = Date()
    var doneAt: Date?
}

/// All tasks + persistence. Every change is saved to JSON immediately.
@Observable
final class Store {
    var todos: [Todo] = [] { didSet { save(); onChange?() } }
    var now = Date()  // refreshed when the popover opens, so day buckets roll over
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let url: URL
    @ObservationIgnored private let cal = Calendar.current

    static let defaultURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacDoIt")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todos.json")
    }()

    init(url: URL = Store.defaultURL) {
        self.url = url
        guard let data = try? Data(contentsOf: url) else { return }
        if let todos = try? Self.decoder.decode([Todo].self, from: data) {
            self.todos = todos
        } else {
            // Never overwrite a file we couldn't read: keep it aside for manual recovery.
            try? FileManager.default.moveItem(at: url, to: url.deletingPathExtension().appendingPathExtension("broken.json"))
        }
    }

    // MARK: Buckets

    private func isToday(_ d: Date) -> Bool { cal.isDate(d, inSameDayAs: now) }

    /// Created today: pending first, done sink to the bottom.
    var today: [Todo] {
        let t = todos.filter { isToday($0.created) }
        return t.filter { $0.doneAt == nil } + t.filter { $0.doneAt != nil }
    }

    /// From earlier days and still pending (or finished today, so the check animation is visible). Oldest first.
    // ponytail: done tasks stay in the JSON forever, prune if the file ever gets big.
    var older: [Todo] {
        todos.filter { !isToday($0.created) && ($0.doneAt.map(isToday) ?? true) }
            .sorted { $0.created < $1.created }
    }

    var pending: Int { todos.filter { $0.doneAt == nil }.count }

    func days(_ t: Todo) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: t.created), to: cal.startOfDay(for: now)).day ?? 0
    }

    // MARK: Actions

    func add(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { todos.insert(Todo(title: title, created: now), at: 0) }
    }

    /// Returns true when the task just became done (time to DO IT).
    @discardableResult
    func toggle(_ id: UUID) -> Bool {
        var done = false
        update(id) { $0.doneAt = $0.doneAt == nil ? Date() : nil; done = $0.doneAt != nil }
        return done
    }

    func update(_ id: UUID, _ change: (inout Todo) -> Void) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        change(&todos[i])
    }

    func delete(_ id: UUID) { todos.removeAll { $0.id == id } }

    // MARK: Persistence

    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = [.prettyPrinted, .sortedKeys]; return e
    }()

    private func save() {
        try? Self.encoder.encode(todos).write(to: url, options: .atomic)
    }
}
