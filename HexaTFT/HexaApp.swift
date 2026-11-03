import SwiftUI

@main struct HexaApp: App {
    @StateObject private var store = Store()
    @StateObject private var meta = MetaStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(meta).preferredColorScheme(.dark).tint(hexaGold)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: Store
    var body: some View {
        TabView {
            NavigationStack { MetaView() }.tabItem { Label("Méta", systemImage: "square.stack.3d.up") }
            NavigationStack { CompanionView() }.tabItem { Label("Partie", systemImage: "play.rectangle") }
            NavigationStack { BoardView() }.tabItem { Label("Plateau", systemImage: "hexagon") }
            NavigationStack { CodexView() }.tabItem { Label("Codex", systemImage: "books.vertical") }
            NavigationStack { SourcesView() }.tabItem { Label("Sources", systemImage: "globe") }
        }
        .alert("Une opération n’a pas abouti", isPresented: Binding(
            get: { store.error != nil }, set: { if !$0 { store.error = nil } }
        )) { Button("Compris", role: .cancel) { store.error = nil } }
        message: { Text(store.error ?? "") }
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.07)))
    }
}

struct Badge: View {
    let text: String
    var color: Color = .mint
    var body: some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct EntryIcon: View {
    let entry: ReferenceEntry
    var size: CGFloat = 42
    var body: some View {
        Group {
            if let local = UIImage(named: String(entry.id.split(separator: ":").last ?? "")) {
                Image(uiImage: local).resizable().scaledToFill()
            } else {
                AsyncImage(url: URL(string: entry.imageURL)) { image in image.resizable().scaledToFill() }
                placeholder: { Text(entry.initials).font(.caption.bold()).frame(maxWidth: .infinity, maxHeight: .infinity).background(hexaGold.opacity(0.12)) }
            }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: min(8, size / 5)))
        .accessibilityHidden(true)
    }
}
