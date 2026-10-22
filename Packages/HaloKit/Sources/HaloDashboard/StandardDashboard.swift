public extension Dashboard {
    /// What a new iPad starts with: a calm home page, the Mac's health, agents beside a
    /// trackpad, and a desk page for working the Mac from the iPad.
    static var standard: Dashboard {
        Dashboard(pages: [
            DashboardPage(title: "Home", widgets: [
                Widget(kind: .brightness, frame: GridFrame(x: 0, y: 1, width: 1, height: 4)),
                Widget(kind: .clock, frame: GridFrame(x: 2, y: 1, width: 8, height: 3)),
                Widget(kind: .nowPlaying, frame: GridFrame(x: 3, y: 4, width: 6, height: 1)),
                Widget(kind: .volume, frame: GridFrame(x: 11, y: 1, width: 1, height: 4)),
                Widget(kind: .dock, frame: GridFrame(x: 0, y: 7, width: 10, height: 1)),
            ]),
            DashboardPage(title: "Pulse", widgets: [
                Widget(kind: .cpu, frame: GridFrame(x: 1, y: 1, width: 5, height: 2)),
                Widget(kind: .memory, frame: GridFrame(x: 6, y: 1, width: 5, height: 2)),
                Widget(kind: .storage, frame: GridFrame(x: 1, y: 3, width: 5, height: 2)),
                Widget(kind: .network, frame: GridFrame(x: 6, y: 3, width: 5, height: 2)),
                Widget(kind: .dock, frame: GridFrame(x: 0, y: 7, width: 10, height: 1)),
            ]),
            DashboardPage(title: "Agents", widgets: [
                Widget(kind: .agents, frame: GridFrame(x: 1, y: 0, width: 6, height: 7)),
                Widget(kind: .trackpad, frame: GridFrame(x: 8, y: 2, width: 4, height: 5)),
                Widget(kind: .dock, frame: GridFrame(x: 0, y: 7, width: 10, height: 1)),
            ]),
            DashboardPage(title: "Desk", widgets: [
                Widget(kind: .trackpad, frame: GridFrame(x: 0, y: 0, width: 8, height: 8)),
                Widget(kind: .nowPlaying, frame: GridFrame(x: 8, y: 0, width: 4, height: 2)),
                Widget(kind: .deck, frame: GridFrame(x: 8, y: 2, width: 4, height: 4)),
                Widget(kind: .cpu, frame: GridFrame(x: 8, y: 6, width: 4, height: 2)),
            ]),
        ])
    }
}
