// Self-check for Store: day buckets, age, toggle, persistence. Run: ./doit.sh test
import Foundation

let url = FileManager.default.temporaryDirectory.appendingPathComponent("doit-test-\(UUID()).json")
let cal = Calendar.current
let s = Store(url: url)
let ago = { (d: Int) in cal.date(byAdding: .day, value: -d, to: s.now)! }

precondition(s.add("today"))
precondition(!s.add("   "), "blank ignored")
s.todos.append(Todo(title: "old", created: ago(3)))
s.todos.append(Todo(title: "older", created: ago(5)))
s.todos.append(Todo(title: "done yesterday", created: ago(2), doneAt: ago(1)))

precondition(s.today.map(\.title) == ["today"])
precondition(s.older.map(\.title) == ["older", "old"], "oldest first, old done hidden")
precondition(s.days(s.older[0]) == 5)
precondition(s.pending == 3)

precondition(s.toggle(s.older[1].id) == true)
precondition(s.older.map(\.title) == ["older", "old"], "done today stays visible")
precondition(s.pending == 2)
precondition(s.toggle(s.older[1].id) == false, "uncheck")

precondition(Store(url: url).todos.count == 4, "persisted")
try? FileManager.default.removeItem(at: url)
print("✅ all good")
