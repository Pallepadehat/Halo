public extension Dashboard {
    /// A full, considered set of pages: what the demo shows, and a starting point for screenshots.
    /// New installs start from `empty` instead, so the person builds their own.
    static var showcase: Dashboard {
        Dashboard(pages: [
            DashboardPage(title: "Home", widgets: [
                DashboardWidget(kind: .brightness, origin: GridPoint(x: 0, y: 1)),
                DashboardWidget(kind: .clock, family: .large, origin: GridPoint(x: 3, y: 0)),
                DashboardWidget(kind: .nowPlaying, family: .medium, origin: GridPoint(x: 3, y: 4)),
                DashboardWidget(kind: .volume, origin: GridPoint(x: 11, y: 1)),
            ]),
            DashboardPage(title: "Pulse", widgets: [
                DashboardWidget(kind: .cpu, family: .large, origin: GridPoint(x: 0, y: 0)),
                DashboardWidget(kind: .memory, family: .small, origin: GridPoint(x: 6, y: 0)),
                DashboardWidget(kind: .storage, family: .small, origin: GridPoint(x: 9, y: 0)),
                DashboardWidget(kind: .network, family: .medium, origin: GridPoint(x: 6, y: 2)),
                DashboardWidget(kind: .nowPlaying, family: .medium, origin: GridPoint(x: 0, y: 4)),
                DashboardWidget(kind: .clock, family: .medium, origin: GridPoint(x: 6, y: 4)),
            ]),
            DashboardPage(title: "Agents", widgets: [
                DashboardWidget(kind: .agents, family: .large, origin: GridPoint(x: 0, y: 0)),
                DashboardWidget(kind: .trackpad, family: .large, origin: GridPoint(x: 6, y: 0)),
                DashboardWidget(kind: .deck, family: .medium, origin: GridPoint(x: 0, y: 4)),
                DashboardWidget(kind: .cpu, family: .small, origin: GridPoint(x: 6, y: 4)),
                DashboardWidget(kind: .memory, family: .small, origin: GridPoint(x: 9, y: 4)),
            ]),
            DashboardPage(title: "Desk", widgets: [
                DashboardWidget(kind: .trackpad, family: .extraLarge, origin: GridPoint(x: 0, y: 0)),
                DashboardWidget(kind: .nowPlaying, family: .medium, origin: GridPoint(x: 0, y: 4)),
                DashboardWidget(kind: .deck, family: .medium, origin: GridPoint(x: 6, y: 4)),
            ]),
        ])
    }
}
