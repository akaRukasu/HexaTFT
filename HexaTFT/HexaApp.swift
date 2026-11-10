import SwiftUI
import BackgroundTasks

@main struct HexaApp: App {
    @StateObject private var store = Store()
    @StateObject private var meta = MetaStore()
    @StateObject private var tracker = TrackerStore()
    @StateObject private var news = RiotNewsStore()
    private static let refreshIdentifier = "com.example.HexaTFT.refresh"
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(meta).environmentObject(tracker).environmentObject(news).preferredColorScheme(.dark).tint(hexaGold)
        }
        .backgroundTask(.appRefresh(Self.refreshIdentifier)) {
            Self.scheduleRefresh()
            async let metaSync: Void = meta.autoRefresh()
            async let pbeSync: Void = meta.autoRefreshPBE()
            async let newsSync: Void = news.refresh()
            async let riotSync: Void = tracker.autoRefresh()
            _ = await (metaSync, pbeSync, newsSync, riotSync)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: Store
    @EnvironmentObject private var meta: MetaStore
    @EnvironmentObject private var tracker: TrackerStore
    @EnvironmentObject private var news: RiotNewsStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView {
            NavigationStack { MetaView() }.id(meta.selection).tabItem { Label("Méta", systemImage: "square.stack.3d.up") }
            NavigationStack { CompanionView() }.tabItem { Label("Partie", systemImage: "play.rectangle") }
            NavigationStack { PatchHubView() }.tabItem { Label("Patches", systemImage: "calendar") }
            NavigationStack { TrackerView() }.tabItem { Label("Tracker", systemImage: "chart.xyaxis.line") }
            NavigationStack { UltimateLibraryView() }.tabItem { Label("Plus", systemImage: "ellipsis") }
        }
        .onChange(of: meta.reference?.version, initial: true) { _, _ in store.showReference(meta.reference) }
        .onChange(of: scenePhase) { _, phase in if phase == .background { HexaApp.scheduleRefresh() } }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                async let metaSync: Void = meta.autoRefresh()
                async let riotSync: Void = tracker.autoRefresh()
                async let pbeSync: Void = meta.autoRefreshPBE()
                async let newsSync: Void = news.refresh()
                _ = await (metaSync, riotSync, pbeSync, newsSync)
                try? await Task.sleep(for: .seconds(60))
            }
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
            if entry.set == "18", let local = UIImage(named: String(entry.id.split(separator: ":").last ?? "")) {
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
