import AppKit
import SwiftUI

let shiaFace = Bundle.main.image(forResource: "face") ?? NSImage()
let doItGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
let doItTeal = Color(red: 0.19, green: 0.84, blue: 0.78)
let doItGradient = LinearGradient(colors: [doItGreen, doItTeal], startPoint: .leading, endPoint: .trailing)
let memes = ["doit", "yesyoucan"]  // gifs in Resources/, one is picked at random

// MARK: - Popover ("Liquid Glass": light, translucent, pastel glow)

struct ContentView: View {
    @Bindable var store: Store
    @AppStorage("width") private var width = 380.0
    @AppStorage("height") private var height = 580.0
    @State private var draft = ""
    @State private var expanded: UUID?
    @State private var meme: String?
    @State private var memeCount = 0
    @State private var drift = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        // Buckets are filter+sort: compute once per body, not once per read.
        let today = store.today, older = store.older, pending = store.pending
        let visible = today + older
        let done = visible.filter { $0.doneAt != nil }.count
        ZStack {
            background
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    header(done: done, total: visible.count)
                    progress(visible.isEmpty ? 0 : Double(done) / Double(visible.count))
                    input
                }
                .padding(.horizontal, 18)
                list(today: today, older: older)
                footer(pending: pending).padding(.horizontal, 18)
            }
            if let meme {
                MemeOverlay(gif: meme)
                    .onTapGesture { self.meme = nil }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .frame(width: width, height: height)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: meme)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: expanded)
    }

    // Soft pastel blobs drifting behind the native popover glass.
    // Radial gradients, not blurred circles: a 90pt blur re-rendered every frame of a forever animation is the
    // single most expensive thing this view could do. The overlay keeps the big blobs out of layout.
    private var background: some View {
        Color.clear.overlay {
            ZStack {
                Blob(color: Color(red: 0.66, green: 0.9, blue: 0.81), radius: 300)
                    .offset(x: drift ? -60 : -150, y: drift ? -170 : -250)
                Blob(color: Color(red: 1, green: 0.83, blue: 0.88), radius: 280)
                    .offset(x: drift ? 170 : 110, y: drift ? -30 : -130)
                Blob(color: Color(red: 0.71, green: 0.85, blue: 1), radius: 330)
                    .offset(x: drift ? -70 : 50, y: drift ? 270 : 200)
            }
            .opacity(0.75)
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeInOut(duration: 10).repeatForever()) { drift = true } }
    }

    private func header(done: Int, total: Int) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: shiaFace).resizable().frame(width: 40, height: 40).clipShape(Circle())
                .shadow(color: doItGreen.opacity(0.4), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text("Mac Do It").font(.system(size: 20, weight: .bold)).tracking(-0.4)
                Text(store.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(done) of \(total)").font(.system(size: 22, weight: .bold)).tracking(-0.5)
                    .contentTransition(.numericText())
                Text("done").font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .padding(.top, 18)
    }

    private func progress(_ fraction: Double) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.07))
                Capsule().fill(doItGradient)
                    .frame(width: fraction == 0 ? 0 : max(6, g.size.width * fraction))
                    .shadow(color: doItGreen.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 6)
        .padding(.vertical, 16)
    }

    private var input: some View {
        HStack(spacing: 10) {
            Button(action: add) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 22, height: 22).background(doItGreen, in: Circle())
                    .rotationEffect(.degrees(inputFocused ? 90 : 0))
                    .scaleEffect(draft.isEmpty ? 1 : 1.15)
            }
            .buttonStyle(.icon)
            TextField("What are you gonna do today?", text: $draft)
                .textFieldStyle(.plain).font(.system(size: 14)).focused($inputFocused).onSubmit(add)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(inputFocused ? doItGreen.opacity(0.55) : .black.opacity(0.06), lineWidth: inputFocused ? 1.5 : 1))
        .shadow(color: inputFocused ? doItGreen.opacity(0.18) : .clear, radius: 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: inputFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: draft.isEmpty)
    }

    private func list(today: [Todo], older: [Todo]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                if today.isEmpty && older.isEmpty { emptyState }
                if !today.isEmpty {
                    section("Today", today.count)
                    ForEach(today) { row($0) }
                }
                if !older.isEmpty {
                    section("Yesterday you said tomorrow", older.count)
                    ForEach(older) { row($0) }
                }
            }
            // Inside the scroll view so check sparks aren't clipped at the edges.
            .padding(.horizontal, 18).padding(.vertical, 6)
        }
        .scrollIndicators(.never)
    }

    private func section(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)").contentTransition(.numericText())
        }
        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
        .padding(.horizontal, 4).padding(.top, 14).padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(nsImage: shiaFace).resizable().frame(width: 56, height: 56).clipShape(Circle())
                .shadow(color: doItGreen.opacity(0.4), radius: 8, y: 4)
            Text("Nothing to do?").font(.system(size: 15, weight: .semibold))
            Text("Don't let your dreams be dreams.\nWrite something down.")
                .font(.system(size: 12.5)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
    }

    private func footer(pending: Int) -> some View {
        HStack(spacing: 10) {
            Text(pending == 0 ? "All done · You did it. 🏆" : "\(pending) left · Just do it.")
                .contentTransition(.numericText())
            Spacer()
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .buttonStyle(.icon).help("Quit Mac Do It")
            ResizeGrip(width: $width, height: $height)
        }
        .font(.system(size: 12)).foregroundStyle(.secondary)
        .padding(.vertical, 10)
    }

    private func row(_ todo: Todo) -> some View {
        // .equatable(): only rows whose todo/age/expansion changed re-render (e.g. typing notes touches one row).
        TodoRow(
            todo: todo, days: store.days(todo), isExpanded: expanded == todo.id,
            onExpand: { expanded = expanded == todo.id ? nil : todo.id },
            notes: Binding(get: { todo.notes }, set: { v in store.update(todo.id) { $0.notes = v } }),
            onToggle: { toggle(todo.id) },
            onDelete: { NSSound(named: "Pop")?.play(); withAnimation(listSpring) { store.delete(todo.id) } })
        .equatable()
    }

    // Animate list moves explicitly per action. An implicit `.animation(value: store.todos)` on the root
    // compared the whole array and ran a spring over the whole tree on every notes keystroke.
    private let listSpring = Animation.spring(response: 0.45, dampingFraction: 0.78)

    private func add() {
        withAnimation(listSpring) { store.add(draft) }
        draft = ""
    }

    private func toggle(_ id: UUID) {
        guard withAnimation(listSpring, { store.toggle(id) }) else { return }
        memeCount += 1
        let current = memeCount
        // Let the check animation land first, then Shia.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard memeCount == current else { return }
            meme = memes.randomElement()
            Sound.play("doit")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.35) { if memeCount == current { meme = nil } }
    }
}

// MARK: - Row

struct TodoRow: View, Equatable {
    let todo: Todo
    let days: Int
    let isExpanded: Bool
    let onExpand: () -> Void
    @Binding var notes: String
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var hover = false
    @State private var flash = false   // green flash on check
    @State private var dying = false   // red flash before delete
    @State private var shakes = 0.0

    private var done: Bool { todo.doneAt != nil }

    static func == (a: Self, b: Self) -> Bool { a.todo == b.todo && a.days == b.days && a.isExpanded == b.isExpanded }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CheckBox(done: done, action: onToggle)
            VStack(alignment: .leading, spacing: 6) {
                // Only this line toggles notes; a tap gesture over the buttons would swallow their clicks.
                HStack(alignment: .top, spacing: 8) {
                    Text(todo.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(done ? Color(nsColor: .tertiaryLabelColor) : .primary)
                        .lineLimit(isExpanded ? nil : 2)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Color(nsColor: .tertiaryLabelColor)).frame(height: 1.5)
                                .scaleEffect(x: done ? 1 : 0, anchor: .leading)
                                .animation(.easeOut(duration: 0.35).delay(done ? 0.12 : 0), value: done)
                        }
                    if !todo.notes.isEmpty && !isExpanded {
                        Image(systemName: "text.alignleft").font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 3)
                    }
                    Spacer(minLength: 4)
                    if days > 0 && !done { AgeBadge(days: days) }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onExpand)

                if isExpanded {
                    TextField("Add notes…", text: $notes, axis: .vertical)
                        .textFieldStyle(.plain).font(.system(size: 12.5)).foregroundStyle(.secondary)
                        .lineLimit(2...12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            if hover {
                Button(action: destroy) { Image(systemName: "trash").font(.system(size: 12)) }
                    .buttonStyle(.icon).foregroundStyle(.red.opacity(0.75)).padding(.top, 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(isExpanded ? 0.85 : hover ? 0.45 : 0))
                .shadow(color: .black.opacity(isExpanded ? 0.07 : 0), radius: 12, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(dying ? Color.red.opacity(0.15) : doItGreen.opacity(flash ? 0.16 : 0))
                .allowsHitTesting(false)
        }
        .modifier(Shake(phase: shakes))
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
        .onChange(of: done) { _, nowDone in
            if nowDone {
                flash = true
                withAnimation(.easeOut(duration: 0.7).delay(0.15)) { flash = false }
            } else {
                withAnimation(.linear(duration: 0.4)) { shakes += 1 }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .modifier(active: Poof(p: 1), identity: Poof(p: 0))))
    }

    /// Red flash + shake, then the row poofs away.
    private func destroy() {
        withAnimation(.linear(duration: 0.25)) { dying = true; shakes += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: onDelete)
    }
}

struct CheckBox: View {
    let done: Bool
    let action: () -> Void
    @State private var bursts = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().strokeBorder(.black.opacity(0.22), lineWidth: 1.8).opacity(done ? 0 : 1)
                Circle().fill(doItGreen).scaleEffect(done ? 1 : 0.01).opacity(done ? 1 : 0)
                Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                    .scaleEffect(done ? 1 : 0.2).rotationEffect(.degrees(done ? 0 : -60)).opacity(done ? 1 : 0)
            }
            .frame(width: 20, height: 20)
            .contentShape(Circle())  // whole circle clickable, not just the ring
            .shadow(color: done ? doItGreen.opacity(0.45) : .clear, radius: 5, y: 2)
            .animation(.spring(response: 0.35, dampingFraction: 0.5), value: done)
        }
        .buttonStyle(.icon)
        .overlay { if bursts > 0 { Sparks().id(bursts).allowsHitTesting(false) } }
        .onChange(of: done) { _, nowDone in if nowDone { bursts += 1 } }
    }
}

/// Ripple ring + sparks flying out of the checkbox. Re-created per check via `.id`.
struct Sparks: View {
    @State private var go = false

    var body: some View {
        ZStack {
            Circle().stroke(doItGreen, lineWidth: 2).scaleEffect(go ? 2.4 : 1).opacity(go ? 0 : 0.8)
            ForEach(0..<10, id: \.self) { i in
                let a = Double(i) / 10 * 2 * .pi
                Circle().fill(i.isMultiple(of: 2) ? doItGreen : doItTeal).frame(width: 4, height: 4)
                    .offset(x: go ? cos(a) * 24 : 0, y: go ? sin(a) * 24 : 0)
                    .scaleEffect(go ? 0.3 : 1)
                    .opacity(go ? 0 : 1)
            }
        }
        .frame(width: 20, height: 20)
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { go = true } }
    }
}

/// Horizontal wobble; each +1 on `phase` = one shake.
struct Shake: GeometryEffect {
    var phase: Double
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(phase * .pi * 6) * 5, y: 0))
    }
}

/// Delete transition: shrink, blur and drift away.
struct Poof: ViewModifier {
    let p: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 - 0.2 * p)
            .blur(radius: 12 * p)
            .offset(x: 50 * p)
            .opacity(1 - p)
    }
}

/// Soft glow that looks like a heavily blurred circle, at the cost of a plain gradient fill.
struct Blob: View {
    let color: Color
    let radius: Double

    var body: some View {
        RadialGradient(colors: [color, color.opacity(0.6), color.opacity(0)], center: .center, startRadius: 0, endRadius: radius)
            .frame(width: radius * 2, height: radius * 2)
    }
}

/// "4 days" pill, orange → red as it ages.
struct AgeBadge: View {
    let days: Int

    var body: some View {
        let color = days >= 3 ? Color(red: 0.88, green: 0.21, blue: 0.17) : Color(red: 0.79, green: 0.44, blue: 0)
        Text("\(days) day\(days == 1 ? "" : "s")")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .help("Sitting here for \(days) day\(days == 1 ? "" : "s"). JUST DO IT.")
    }
}

/// Drag to resize the popover; size lives in @AppStorage so it's saved instantly.
struct ResizeGrip: View {
    @Binding var width: Double
    @Binding var height: Double
    @State private var start: (mouse: NSPoint, width: Double, height: Double)?

    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 10))
            .frame(width: 14, height: 14)
            .modifier(HoverEffect(pressed: start != nil))
            .onHover { inside in
                guard inside else { return NSCursor.pop() }
                if #available(macOS 15, *) { NSCursor.frameResize(position: .bottomRight, directions: .all).push() }
                else { NSCursor.crosshair.push() }
            }
            .help("Drag to resize")
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Screen coords: the popover moves while resizing, so view-local deltas would jitter.
                    let m = NSEvent.mouseLocation
                    let s = start ?? (m, width, height)
                    start = s
                    // ponytail: x2 because the popover grows from its center; off when clamped at the screen edge.
                    width = min(max(s.width + (m.x - s.mouse.x) * 2, 320), 900)
                    height = min(max(s.height + (s.mouse.y - m.y), 360), 1100)
                }
                .onEnded { _ in start = nil })
    }
}

/// Hover halo + grow, squish while pressed. Shared by every button and the resize grip.
struct HoverEffect: ViewModifier {
    var pressed = false
    @State private var hover = false

    func body(content: Content) -> some View {
        content
            .background(Circle().fill(.black.opacity(pressed ? 0.12 : hover ? 0.07 : 0)).padding(-5))
            .contentShape(Circle().inset(by: -5))  // the halo is clickable too
            .scaleEffect(pressed ? 0.85 : hover ? 1.12 : 1)
            .onHover { hover = $0 }
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hover)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(HoverEffect(pressed: configuration.isPressed))
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
}

// MARK: - The meme

struct MemeOverlay: View {
    let gif: String
    @State private var burst = false
    private let confetti: [Color] = [doItGreen, doItTeal, .pink, .blue, .yellow, .orange]

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            ForEach(0..<28, id: \.self) { i in
                let a = Double(i) / 28 * 2 * .pi
                let r = Double(150 + (i * 37) % 90)
                RoundedRectangle(cornerRadius: 2).fill(confetti[i % confetti.count])
                    .frame(width: 6, height: 11)
                    .rotationEffect(.degrees(burst ? Double(i * 47) : 0))
                    .offset(x: burst ? cos(a) * r : 0, y: burst ? sin(a) * r + 40 : 0)
                    .opacity(burst ? 0 : 1)
            }
            VStack(spacing: 14) {
                GIFView(name: gif)
                    .aspectRatio(1.34, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: 3))
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    .scaleEffect(burst ? 1 : 0.9)
                Text("Just did it.").font(.system(size: 30, weight: .bold)).tracking(-0.6).foregroundStyle(doItGradient)
                Text("Tap to keep going").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) { burst = true } }
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
