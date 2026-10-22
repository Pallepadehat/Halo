import CoreGraphics
import Foundation
import Testing
@testable import HaloDashboard

@Suite struct DashboardPageTests {
    @Test func addingFillsTheFirstFreeSpotRowByRow() throws {
        var page = DashboardPage(title: "Test")
        let first = try page.adding(.cpu)
        let second = try page.adding(.cpu)
        #expect(first.frame == GridFrame(x: 0, y: 0, width: 3, height: 2))
        #expect(second.frame == GridFrame(x: 3, y: 0, width: 3, height: 2))
    }

    @Test func addingFallsBackToASmallerFamilyWhenTheDefaultWontFit() throws {
        var page = DashboardPage(title: "Test", widgets: [
            DashboardWidget(kind: .trackpad, family: .extraLarge, origin: GridPoint(x: 0, y: 0)),
            // Leaves three columns free on each side of the bottom row: room for Small only.
            DashboardWidget(kind: .clock, family: .medium, origin: GridPoint(x: 3, y: 4)),
        ])
        let clock = try page.adding(.clock)
        #expect(clock.family == .small)
        #expect(clock.origin == GridPoint(x: 0, y: 4))
    }

    @Test func aFullPageRefusesNewWidgets() {
        var page = DashboardPage(title: "Full", widgets: [
            DashboardWidget(kind: .trackpad, family: .extraLarge, origin: GridPoint(x: 0, y: 0)),
            DashboardWidget(kind: .agents, family: .medium, origin: GridPoint(x: 0, y: 4)),
            DashboardWidget(kind: .agents, family: .medium, origin: GridPoint(x: 6, y: 4)),
        ])
        let added = page.add(.cpu)
        #expect(added == nil)
    }

    @Test func movingIntoAnotherWidgetIsRefused() throws {
        var page = DashboardPage(title: "Test")
        let a = try page.adding(.cpu)
        let b = try page.adding(.memory)
        let overlapping = page.move(b.id, to: GridPoint(x: 1, y: 0))
        let clear = page.move(b.id, to: GridPoint(x: 0, y: 4))
        #expect(!overlapping)
        #expect(clear)
        #expect(page.widget(a.id)?.origin == GridPoint(x: 0, y: 0))
    }

    @Test func resizingOnlyOffersTheKindsOwnFamilies() throws {
        var page = DashboardPage(title: "Test")
        let slider = try page.adding(.volume)
        let toLarge = page.resize(slider.id, to: .large)
        #expect(!toLarge)

        let clock = try page.adding(.clock)
        let toLargeClock = page.resize(clock.id, to: .large)
        #expect(toLargeClock)
        #expect(page.widget(clock.id)?.family == .large)
    }

    @Test func growingNearTheEdgeNudgesTheWidgetBackOntoTheGrid() throws {
        var page = DashboardPage(title: "Test", widgets: [
            DashboardWidget(kind: .clock, family: .small, origin: GridPoint(x: 9, y: 4)),
        ])
        let id = page.widgets[0].id
        let grown = page.resize(id, to: .large)
        #expect(grown)
        #expect(page.widget(id)?.frame == GridFrame(x: 6, y: 2, width: 6, height: 4))
    }

    @Test func showcasePagesAreValid() {
        for page in Dashboard.showcase.pages {
            for widget in page.widgets {
                #expect(widget.frame.fitsGrid, "\(widget.kind) is off the grid on \(page.title)")
                #expect(page.isAvailable(widget.frame, ignoring: widget.id), "\(widget.kind) overlaps on \(page.title)")
                #expect(widget.kind.families.contains(widget.family), "\(widget.kind) doesn't come in \(widget.family)")
            }
        }
    }

    @Test func everyKindsDefaultFamilyIsOneItSupports() {
        for kind in WidgetKind.allCases {
            #expect(kind.families.contains(kind.defaultFamily))
            #expect(kind.families == kind.families.sorted())
        }
    }
}

@Suite struct DashboardTests {
    @Test func aNewInstallStartsWithOneEmptyPage() {
        let dashboard = Dashboard.empty
        #expect(dashboard.pages.count == 1)
        #expect(dashboard.isEmpty)
    }

    @Test func theLastPageCannotBeRemoved() {
        var dashboard = Dashboard.empty
        dashboard.removePage(dashboard.pages[0].id)
        #expect(dashboard.pages.count == 1)
    }

    @Test func newPagesGoAfterTheCurrentOne() {
        var dashboard = Dashboard.showcase
        let page = dashboard.addPage(after: dashboard.pages[0].id)
        #expect(dashboard.index(of: page.id) == 1)
    }

    @Test func findsTheFirstPageWithAWidgetKind() {
        #expect(Dashboard.showcase.firstPage(containing: .agents)?.title == "Agents")
    }

    @Test func survivesARoundTripThroughJSON() throws {
        var dashboard = Dashboard.showcase
        var page = dashboard.pages[3]
        page.setOptions(WidgetOptions(deckActions: ["builtin.lockScreen"], gestureActions: ["threeFingerTap": "shortcut.Focus"]), for: page.widgets[2].id)
        dashboard[page: page.id] = page
        let data = try JSONEncoder().encode(dashboard)
        #expect(try JSONDecoder().decode(Dashboard.self, from: data) == dashboard)
    }

    @Test func layoutsFromAnOlderGridAreNotReused() {
        let old = #"{"pages":[{"id":"7C9D5B7E-2F4B-4F5E-9C1A-1E2D3C4B5A69","title":"Old","widgets":[]}]}"#
        #expect(throws: Dashboard.IncompatibleVersion.self) {
            try JSONDecoder().decode(Dashboard.self, from: Data(old.utf8))
        }
    }

    @Test func skipsWidgetsThisBuildCannotRead() throws {
        let json = """
        {"id":"7C9D5B7E-2F4B-4F5E-9C1A-1E2D3C4B5A69","title":"Mixed","widgets":[
          {"id":"1C9D5B7E-2F4B-4F5E-9C1A-1E2D3C4B5A69","kind":"dock","family":"medium","origin":{"x":0,"y":0}},
          {"id":"2C9D5B7E-2F4B-4F5E-9C1A-1E2D3C4B5A69","kind":"volume","family":"large","origin":{"x":0,"y":0}},
          {"id":"3C9D5B7E-2F4B-4F5E-9C1A-1E2D3C4B5A69","kind":"clock","family":"small","origin":{"x":0,"y":0}}
        ]}
        """
        let page = try JSONDecoder().decode(DashboardPage.self, from: Data(json.utf8))
        #expect(page.widgets.map(\.kind) == [.clock])
    }
}

@Suite struct GridGeometryTests {
    // 12 columns of 100 with 18 between: 1398 wide. 6 rows of 100: 690 tall.
    let geometry = GridGeometry(bounds: CGSize(width: 1398, height: 690), spacing: 18)

    @Test func cellsAndSpansIncludeTheGutters() {
        #expect(geometry.cellSize == CGSize(width: 100, height: 100))
        #expect(geometry.rect(for: GridFrame(x: 1, y: 2, width: 2, height: 1)) == CGRect(x: 118, y: 236, width: 218, height: 100))
        #expect(geometry.size(of: .medium) == CGSize(width: 690, height: 218))
    }

    @Test func dragsSnapToTheNearestCellAndStayOnTheGrid() {
        #expect(geometry.nearestOrigin(to: CGPoint(x: 170, y: 40), for: GridSize(width: 3, height: 2)) == GridPoint(x: 1, y: 0))
        #expect(geometry.nearestOrigin(to: CGPoint(x: 5000, y: 5000), for: GridSize(width: 3, height: 2)) == GridPoint(x: 9, y: 4))
    }

    @Test func resizeHandleSnapsToTheNearestFamily() {
        let families = WidgetKind.clock.families
        let pulledWide = geometry.nearestFamily(reaching: CGPoint(x: 700, y: 230), from: GridPoint(x: 0, y: 0), among: families)
        let pulledBig = geometry.nearestFamily(reaching: CGPoint(x: 700, y: 460), from: GridPoint(x: 0, y: 0), among: families)
        #expect(pulledWide == .medium)
        #expect(pulledBig == .large)
    }
}

private extension DashboardPage {
    /// `add`, failing the test if the page had no room.
    mutating func adding(_ kind: WidgetKind) throws -> DashboardWidget {
        let widget = add(kind)
        return try #require(widget)
    }
}
