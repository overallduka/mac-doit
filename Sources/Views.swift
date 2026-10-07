import AppKit
import SwiftUI

let shiaFace = Bundle.main.image(forResource: "face") ?? NSImage()
let doItGreen = Color(red: 0.1, green: 0.9, blue: 0.4)
let doItGradient = LinearGradient(colors: [doItGreen, .mint, .cyan], startPoint: .leading, endPoint: .trailing)
let memes = ["doit", "yesyoucan"]  // gifs in Resources/, one is picked at random

// MARK: - Popover

struct ContentView: View {
    @Bindable var store: Store
    @AppStorage("width") private var width = 360.0
    @AppStorage("height") private var height = 540.0
    @State private var draft = ""
    @State private var expanded: UUID?
    @State private var meme: String?
    @State private var memeCount = 0
    @State private var drift = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                input
                list
                footer
            }
            if let meme {
                MemeOverlay(gif: meme)
                    .onTapGesture { self.meme = nil }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .frame(width: width, height: height)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: store.todos)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: meme)
        .animation(.easeInOut(duration: 0.25), value: expanded)
    }

    // Dark base with two slowly drifting glow blobs.
    private var background: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08)
            Circle().fill(doItGreen.opacity(0.3)).frame(width: 260).blur(radius: 80)
                .offset(x: drift ? 120 : -80, y: drift ? -180 : -100)
            Circle().fill(Color.purple.opacity(0.35)).frame(width: 240).blur(radius: 90)
                .offset(x: drift ? -120 : 90, y: drift ? 200 : 120)
        }
        .onAppear { withAnimation(.easeInOut(duration: 8).repeatForever()) { drift = true } }
    }

    private var header: some View {
        let visible = store.today + store.older
        let done = visible.filter { $0.doneAt != nil }.count
        return HStack(spacing: 12) {
            Image(nsImage: shiaFace).resizable().frame(width: 44, height: 44).clipShape(Circle())
                .overlay(Circle().stroke(doItGradient, lineWidth: 2))
                .shadow(color: doItGreen.opacity(0.6), radius: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text("MAC DO IT").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(doItGradient)
                Text(store.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            ProgressRing(done: done, total: visible.count)
        }
        .padding(16)
    }

    private var input: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(doItGreen)
                .rotationEffect(.degrees(inputFocused ? 90 : 0))
            TextField("What are you gonna DO today?", text: $draft)
                .textFieldStyle(.plain).focused($inputFocused).onSubmit(add)
        }
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(inputFocused ? AnyShapeStyle(doItGradient) : AnyShapeStyle(.white.opacity(0.1))))
        .animation(.spring, value: inputFocused)
        .padding(.horizontal, 16).padding(.bottom, 10)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 6) {
                if store.today.isEmpty && store.older.isEmpty {
                    emptyState
                }
                ForEach(store.today) { row($0) }
                if !store.older.isEmpty {
                    HStack {
                        Text("YESTERDAY YOU SAID TOMORROW").font(.caption.weight(.heavy)).foregroundStyle(.orange).fixedSize()
                        Rectangle().fill(.orange.opacity(0.3)).frame(height: 1)
                    }
                    .padding(.top, 12)
                    ForEach(store.older) { row($0) }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
        .scrollIndicators(.never)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("💪").font(.system(size: 44))
            Text("Nothing to do?").font(.headline)
            Text("Don't let your dreams be dreams.\nWrite something down. DO IT.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    private var footer: some View {
        HStack {
            Text(store.pending == 0 ? "All done. You did it. 🏆" : "\(store.pending) left — make your dreams come true")
                .font(.caption).foregroundStyle(.secondary).contentTransition(.numericText())
            Spacer()
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Quit Mac Do It")
            ResizeGrip(width: $width, height: $height)
        }
        .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 8)
        .background(.black.opacity(0.25))
    }

    private func row(_ todo: Todo) -> some View {
        TodoRow(
            todo: todo, days: store.days(todo), expanded: $expanded,
            notes: Binding(get: { todo.notes }, set: { v in store.update(todo.id) { $0.notes = v } }),
            onToggle: { toggle(todo.id) },
            onDelete: { store.delete(todo.id) })
    }

    private func add() {
        store.add(draft)
        draft = ""
    }

    private func toggle(_ id: UUID) {
        guard store.toggle(id) else { return }
        meme = memes.randomElement()
        Sound.play("doit")
        memeCount += 1
        let current = memeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { if memeCount == current { meme = nil } }
    }
}

// MARK: - Row

struct TodoRow: View {
    let todo: Todo
    let days: Int
    @Binding var expanded: UUID?
    @Binding var notes: String
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var hover = false

    private var done: Bool { todo.doneAt != nil }
    private var isExpanded: Bool { expanded == todo.id }
    private var overdue: Bool { days > 0 && !done }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                CheckBox(done: done, action: onToggle)
                Text(todo.title)
                    .strikethrough(done, color: doItGreen)
                    .foregroundStyle(done ? .secondary : .primary)
                    .lineLimit(isExpanded ? nil : 2)
                if !todo.notes.isEmpty && !isExpanded {
                    Image(systemName: "text.alignleft").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if overdue { AgeBadge(days: days) }
                if hover {
                    Button(action: onDelete) { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(.red.opacity(0.8)).transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { expanded = isExpanded ? nil : todo.id }

            if isExpanded {
                TextField("Notes, details, excuses…", text: $notes, axis: .vertical)
                    .textFieldStyle(.plain).font(.callout).lineLimit(3...12)
                    .padding(8)
                    .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(hover || isExpanded ? 0.1 : 0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(overdue ? Color.orange.opacity(0.45) : .white.opacity(0.06)))
        .opacity(done ? 0.6 : 1)
        .scaleEffect(hover ? 1.015 : 1)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)))
    }
}

struct CheckBox: View {
    let done: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(.white.opacity(done ? 0 : 0.35), lineWidth: 2)
                Circle().fill(doItGradient).scaleEffect(done ? 1 : 0.01).opacity(done ? 1 : 0)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .black)).foregroundStyle(.black)
                    .scaleEffect(done ? 1 : 0.3).opacity(done ? 1 : 0)
            }
            .frame(width: 22, height: 22)
            .shadow(color: done ? doItGreen.opacity(0.8) : .clear, radius: 6)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: done)
        }
        .buttonStyle(.plain)
    }
}

/// "🔥 3d" — gets hotter the longer a task sits there.
struct AgeBadge: View {
    let days: Int

    var body: some View {
        let color: Color = days >= 4 ? .red : days >= 2 ? .orange : .yellow
        HStack(spacing: 3) {
            Image(systemName: "flame.fill").symbolEffect(.pulse, isActive: days >= 3)
            Text("\(days)d")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
        .help("Sitting here for \(days) day\(days == 1 ? "" : "s"). JUST DO IT.")
    }
}

struct ProgressRing: View {
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.1), lineWidth: 5)
            Circle().trim(from: 0, to: total == 0 ? 0 : Double(done) / Double(total))
                .stroke(AngularGradient(colors: [doItGreen, .cyan, doItGreen], center: .center),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: done)
            Text("\(done)/\(total)").font(.caption2.weight(.bold).monospacedDigit())
        }
        .frame(width: 42, height: 42)
    }
}

/// Drag to resize the popover; size lives in @AppStorage so it's saved instantly.
struct ResizeGrip: View {
    @Binding var width: Double
    @Binding var height: Double
    @State private var start: (mouse: NSPoint, width: Double, height: Double)?

    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.caption).foregroundStyle(.secondary)
            .frame(width: 22, height: 22).contentShape(Rectangle())
            .help("Drag to resize")
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Screen coords: the popover moves while resizing, so view-local deltas would jitter.
                    let m = NSEvent.mouseLocation
                    let s = start ?? (m, width, height)
                    start = s
                    // ponytail: x2 because the popover grows from its center; off when clamped at the screen edge.
                    width = min(max(s.width + (m.x - s.mouse.x) * 2, 300), 900)
                    height = min(max(s.height + (s.mouse.y - m.y), 320), 1100)
                }
                .onEnded { _ in start = nil })
    }
}

// MARK: - The meme

struct MemeOverlay: View {
    let gif: String
    @State private var burst = false

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            ForEach(0..<18, id: \.self) { i in
                let angle = Double(i) / 18 * 2 * .pi
                Text(["💪", "🔥", "✅", "⚡️"][i % 4]).font(.title)
                    .offset(x: burst ? cos(angle) * 190 : 0, y: burst ? sin(angle) * 190 : 0)
                    .scaleEffect(burst ? 1.3 : 0.2)
                    .opacity(burst ? 0 : 1)
            }
            VStack(spacing: 14) {
                GIFView(name: gif)
                    .aspectRatio(1.3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: doItGreen.opacity(0.7), radius: 24)
                Text("JUST DID IT!")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(doItGradient)
                    .scaleEffect(burst ? 1 : 0.5)
            }
            .padding(24)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { burst = true } }
    }
}

struct GIFView: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.image = Bundle.main.url(forResource: name, withExtension: "gif").flatMap(NSImage.init(contentsOf:))
        view.animates = true
        view.imageScaling = .scaleProportionallyUpOrDown
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {}
}

enum Sound {
    private static var current: NSSound?

    static func play(_ name: String) {
        current?.stop()
        current = Bundle.main.url(forResource: name, withExtension: "mp3").flatMap { NSSound(contentsOf: $0, byReference: true) }
        current?.play()
    }
}
