public extension Dashboard {
    /// What a new iPad starts with: a calm home page, the Mac's health, agents beside a
    /// trackpad, and a desk page for working the Mac from the iPad. The Dock sits beneath every
    /// page, so it isn't part of any layout.
    static var standard: Dashboard {
        Dashboard(pages: [
            DashboardPage(title: "Home", widgets: [
                DashboardWidget(kind: .brightness, frame: GridFrame(x: 0, y: 1, width: 1, height: 5)),
                DashboardWidget(kind: .clock, frame: GridFrame(x: 2, y: 1, width: 8, height: 4)),
                DashboardWidget(kind: .nowPlaying, frame: GridFrame(x: 3, y: 5, width: 6, height: 1)),
                DashboardWidget(kind: .volume, frame: GridFrame(x: 11, y: 1, width: 1, height: 5)),
            ]),
            DashboardPage(title: "Pulse", widgets: [
                DashboardWidget(kind: .cpu, frame: GridFrame(x: 0, y: 0, width: 6, height: 4)),
                DashboardWidget(kind: .memory, frame: GridFrame(x: 6, y: 0, width: 6, height: 4)),
                DashboardWidget(kind: .storage, frame: GridFrame(x: 0, y: 4, width: 6, height: 4)),
                DashboardWidget(kind: .network, frame: GridFrame(x: 6, y: 4, width: 6, height: 4)),
            ]),
            DashboardPage(title: "Agents", widgets: [
                DashboardWidget(kind: .agents, frame: GridFrame(x: 0, y: 0, width: 7, height: 8)),
                DashboardWidget(kind: .trackpad, frame: GridFrame(x: 8, y: 1, width: 4, height: 7)),
            ]),
            DashboardPage(title: "Desk", widgets: [
                DashboardWidget(kind: .trackpad, frame: GridFrame(x: 0, y: 0, width: 8, height: 8)),
                DashboardWidget(kind: .nowPlaying, frame: GridFrame(x: 8, y: 0, width: 4, height: 2)),
                DashboardWidget(kind: .deck, frame: GridFrame(x: 8, y: 2, width: 4, height: 4)),
                DashboardWidget(kind: .cpu, frame: GridFrame(x: 8, y: 6, width: 4, height: 2)),
            ]),
        ])
    }
}
