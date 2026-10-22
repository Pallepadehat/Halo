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
    /// A finger is on a widget that owns its touches (the trackpad), so paging must not steal them.
    var isWidgetCapturingTouches = false

    @ObservationIgnored private let file: URL?
    private static let log = Logger(subsystem: "app.halo", category: "Dashboard")

    /// - Parameter file: where to persist; `nil` keeps everything in memory (previews, demo).
    init(file: URL? = DashboardStore.defaultFile, fallback: Dashboard = .standard) {
        self.file = file
        let saved = file.flatMap { try? JSONDecoder().decode(Dashboard.self, from: Data(contentsOf: $0)) }
        dashboard = saved ?? fallback
        currentPageID = (saved ?? fallback).pages[0].id
    }

    static let defaultFile = URL.applicationSupportDirectory.appending(path: "dashboard.json", directoryHint: .notDirectory)

    var pages: [DashboardPage] { dashboard.pages }

    var currentPage: DashboardPage {
        dashboard[page: currentPageID] ?? dashboard.pages[0]
    }

    var currentIndex: Int {
        dashboard.index(of: currentPageID) ?? 0
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

    // MARK: - Editing

    /// Returns `false` when the current page has no room left.
    @discardableResult
    func add(_ kind: WidgetKind) -> Bool {
        edit { $0.add(kind) != nil }
    }

    @discardableResult
    func move(_ id: DashboardWidget.ID, to origin: GridPoint) -> Bool {
        edit { $0.move(id, to: origin) }
    }

    @discardableResult
    func resize(_ id: DashboardWidget.ID, to size: GridSize) -> Bool {
        edit { $0.resize(id, to: size) }
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
