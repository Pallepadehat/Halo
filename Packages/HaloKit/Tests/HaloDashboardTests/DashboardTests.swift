import CoreGraphics
import Foundation
import Testing
@testable import HaloDashboard

@Suite struct DashboardPageTests {
    @Test func addingFillsTheFirstFreeSpotRowByRow() throws {
        var page = DashboardPage(title: "Test")
        let first = try page.adding(.cpu)
        let second = try page.adding(.cpu)
        #expect(first.frame == GridFrame(x: 0, y: 0, width: 5, height: 2))
        #expect(second.frame == GridFrame(x: 5, y: 0, width: 5, height: 2))
    }

    @Test func addingShrinksToTheMinimumWhenTheDefaultWontFit() throws {
        var page = DashboardPage(title: "Test", widgets: [
            DashboardWidget(kind: .trackpad, frame: GridFrame(x: 0, y: 0, width: 12, height: 6)),
        ])
        let clock = try page.adding(.clock)
        #expect(clock.frame.size == WidgetKind.clock.minimumSize)
        #expect(clock.frame.y == 6)
    }

    @Test func aFullPageRefusesNewWidgets() {
        var page = DashboardPage(title: "Full", widgets: [
            DashboardWidget(kind: .trackpad, frame: GridFrame(x: 0, y: 0, width: 12, height: 8)),
        ])
        let added = page.add(.cpu)
        #expect(added == nil)
    }

    @Test func movingIntoAnotherWidgetIsRefused() throws {
        var page = DashboardPage(title: "Test")
        let a = try page.adding(.cpu)
        let b = try page.adding(.memory)
        let overlapping = page.move(b.id, to: GridPoint(x: 2, y: 0))
        let clear = page.move(b.id, to: GridPoint(x: 0, y: 4))
        #expect(!overlapping)
        #expect(clear)
        #expect(page.widget(b.id)?.frame.origin == GridPoint(x: 0, y: 4))
        #expect(page.widget(a.id)?.frame.origin == GridPoint(x: 0, y: 0))
    }

    @Test func movingOffTheGridIsRefused() throws {
        var page = DashboardPage(title: "Test")
        let widget = try page.adding(.cpu)
        let moved = page.move(widget.id, to: GridPoint(x: 10, y: 0))
        #expect(!moved)
    }

    @Test func resizingRespectsEachKindsLimits() throws {
        var page = DashboardPage(title: "Test")
        let slider = try page.adding(.volume)
        let resized = page.resize(slider.id, to: GridSize(width: 6, height: 8))
        #expect(resized)
        #expect(page.widget(slider.id)?.frame.size == GridSize(width: 2, height: 8))
    }

    @Test func standardPagesAreValid() {
        for page in Dashboard.standard.pages {
            for widget in page.widgets {
                #expect(widget.frame.fitsGrid, "\(widget.kind) is off the grid on \(page.title)")
                #expect(page.isAvailable(widget.frame, ignoring: widget.id), "\(widget.kind) overlaps on \(page.title)")
                #expect(WidgetKind.allCases.contains(widget.kind))
            }
        }
    }
}

@Suite struct DashboardTests {
    @Test func theLastPageCannotBeRemoved() {
        var dashboard = Dashboard(pages: [])
        #expect(dashboard.pages.count == 1)
        dashboard.removePage(dashboard.pages[0].id)
        #expect(dashboard.pages.count == 1)
    }

    @Test func newPagesGoAfterTheCurrentOne() {
        var dashboard = Dashboard.standard
        let home = dashboard.pages[0].id
        let page = dashboard.addPage(after: home)
        #expect(dashboard.index(of: page.id) == 1)
    }

    @Test func findsTheFirstPageWithAWidgetKind() {
        #expect(Dashboard.standard.firstPage(containing: .agents)?.title == "Agents")
    }

    @Test func skipsWidgetKindsThisBuildDoesNotKnow() throws {
        let json = """
        {"id":"7C9D5B7E-2F4B-4F5E-9C1A-1E2D3C4B5A69","title":"Old","widgets":[
          {"id":"1C9D5B7E-2F4B-4F5E-9C1A-1E2D3C4B5A69","kind":"dock","frame":{"x":0,"y":7,"width":10,"height":1}},
          {"id":"2C9D5B7E-2F4B-4F5E-9C1A-1E2D3C4B5A69","kind":"clock","frame":{"x":2,"y":1,"width":8,"height":3}}
        ]}
        """
        let page = try JSONDecoder().decode(DashboardPage.self, from: Data(json.utf8))
        #expect(page.widgets.map(\.kind) == [.clock])
    }

    @Test func survivesARoundTripThroughJSON() throws {
        let dashboard = Dashboard.standard
        let data = try JSONEncoder().encode(dashboard)
        #expect(try JSONDecoder().decode(Dashboard.self, from: data) == dashboard)
    }
}

@Suite struct GridGeometryTests {
    // 12 columns of 100 with 16 between: 1376 wide. 8 rows of 100: 912 tall.
    let geometry = GridGeometry(bounds: CGSize(width: 1376, height: 912), spacing: 16)

    @Test func cellsAndSpansIncludeTheGutters() {
        #expect(geometry.cellSize == CGSize(width: 100, height: 100))
        #expect(geometry.rect(for: GridFrame(x: 1, y: 2, width: 2, height: 1)) == CGRect(x: 116, y: 232, width: 216, height: 100))
    }

    @Test func dragsSnapToTheNearestCellAndStayOnTheGrid() {
        #expect(geometry.nearestOrigin(to: CGPoint(x: 170, y: 40), for: GridSize(width: 2, height: 2)) == GridPoint(x: 1, y: 0))
        #expect(geometry.nearestOrigin(to: CGPoint(x: 5000, y: 5000), for: GridSize(width: 2, height: 2)) == GridPoint(x: 10, y: 6))
    }

    @Test func resizeHandleSnapsToWholeCells() {
        let size = geometry.nearestSize(reaching: CGPoint(x: 330, y: 220), from: GridPoint(x: 0, y: 0))
        #expect(size == GridSize(width: 3, height: 2))
    }
}

private extension DashboardPage {
    /// `add`, failing the test if the page had no room.
    mutating func adding(_ kind: WidgetKind) throws -> DashboardWidget {
        let widget = add(kind)
        return try #require(widget)
    }
}
