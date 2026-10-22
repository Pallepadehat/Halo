import Foundation
import HaloDashboard
import Observation
import os

/// The person's own arrangement of pages and widgets, saved on the iPad.
@MainActor
@Observable
final class DashboardStore {
    private(set) var dashboard: Dashboard
    var currentPageID: DashboardPage.ID
    var isEditing = false
    var isShowingGallery = false
    /// The widget whose settings are open, from tapping it in edit mode.
    var configuringWidgetID: DashboardWidget.ID?
    /// A finger is on a widget that owns its touches (the trackpad), so paging must not steal them.
    var isWidgetCapturingTouches = false
    /// The size pages lay out in, so the gallery can preview widgets at their real size.
    var pageSize = CGSize(width: 1146, height: 560)

    @ObservationIgnored private let file: URL?
    private static let log = Logger(subsystem: "app.halo", category: "Dashboard")

    /// - Parameters:
    ///   - file: where to persist; `nil` keeps everything in memory (previews, demo).
    ///   - fallback: used when nothing's saved, or the save is from an incompatible version.
    init(file: URL? = DashboardStore.defaultFile, fallback: Dashboard = .empty) {
        self.file = file
        let saved = file.flatMap { try? JSONDecoder().decode(Dashboard.self, from: Data(contentsOf: $0)) }
        let dashboard = saved ?? fallback
        self.dashboard = dashboard
        currentPageID = dashboard.pages[0].id
    }

    static let defaultFile = URL.applicationSupportDirectory.appending(path: "dashboard.json", directoryHint: .notDirectory)

    var pages: [DashboardPage] { dashboard.pages }

    var currentPage: DashboardPage {
        dashboard[page: currentPageID] ?? dashboard.pages[0]
    }

    var currentIndex: Int {
        dashboard.index(of: currentPageID) ?? 0
    }

    /// Nothing placed anywhere yet: the first-launch hello.
    var isEmpty: Bool {
        dashboard.isEmpty
    }

    func widget(_ id: DashboardWidget.ID) -> DashboardWidget? {
        pages.lazy.compactMap { $0.widget(id) }.first
    }

    func show(pageAt index: Int) {
        guard dashboard.pages.indices.contains(index) else { return }
        currentPageID = dashboard.pages[index].id
    }

    /// Brings forward the first page with `kind`, unless the current page already shows it.
    func reveal(_ kind: WidgetKind) {
        guard !isEditing, !currentPage.contains(kind), let page = dashboard.firstPage(containing: kind) else { return }
        currentPageID = page.id
    }

    /// Long-press on an empty dashboard: straight to choosing a first widget.
    func beginAddingWidgets() {
        isEditing = true
        isShowingGallery = true
    }

    // MARK: - Editing

    /// Returns `false` when the current page has no room left.
    @discardableResult
    func add(_ kind: WidgetKind, family: WidgetFamily) -> Bool {
        edit { $0.add(kind, family: family) != nil }
    }

    @discardableResult
    func move(_ id: DashboardWidget.ID, to origin: GridPoint) -> Bool {
        edit { $0.move(id, to: origin) }
    }

    @discardableResult
    func resize(_ id: DashboardWidget.ID, to family: WidgetFamily) -> Bool {
        edit { $0.resize(id, to: family) }
    }

    func setOptions(_ options: WidgetOptions, for id: DashboardWidget.ID) {
        guard let page = pages.first(where: { $0.widget(id) != nil }) else { return }
        var updated = page
        updated.setOptions(options, for: id)
        dashboard[page: page.id] = updated
        save()
    }

    func remove(_ id: DashboardWidget.ID) {
        edit { page in
            page.remove(id)
            return true
        }
    }

    func renameCurrentPage(_ title: String) {
        edit { page in
            page.title = title
            return true
        }
    }

    func addPage() {
        let page = dashboard.addPage(after: currentPageID)
        currentPageID = page.id
        save()
    }

    func removeCurrentPage() {
        let index = currentIndex
        dashboard.removePage(currentPageID)
        currentPageID = dashboard.pages[min(index, dashboard.pages.count - 1)].id
        save()
    }

    @discardableResult
    private func edit(_ change: (inout DashboardPage) -> Bool) -> Bool {
        var page = currentPage
        guard change(&page) else { return false }
        dashboard[page: page.id] = page
        save()
        return true
    }

    private func save() {
        guard let file else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(dashboard).write(to: file, options: .atomic)
        } catch {
            Self.log.error("Could not save the dashboard: \(error, privacy: .public)")
        }
    }
}
