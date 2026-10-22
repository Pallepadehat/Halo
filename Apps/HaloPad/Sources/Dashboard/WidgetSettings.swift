import HaloCore
import HaloDashboard
import HaloTrackpad
import SwiftUI

/// Edit Widget: the settings of one widget, opened by tapping it in edit mode.
struct WidgetSettings: View {
    @Environment(DashboardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let widget: DashboardWidget

    var body: some View {
        NavigationStack {
            Group {
                switch widget.kind {
                case .deck: DeckConfiguration(widget: widget)
                case .trackpad: TrackpadConfiguration(widget: widget)
                default: EmptyView()
                }
            }
            .navigationTitle(widget.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationSizing(.form)
    }
}

/// Choose which actions the Deck shows, and drag them into order.
private struct DeckConfiguration: View {
    @Environment(PadModel.self) private var model
    @Environment(DashboardStore.self) private var store
    let widget: DashboardWidget

    @State private var chosen: [String] = []

    var body: some View {
        List {
            Section {
                ForEach(chosen, id: \.self) { id in
                    if let action = action(id) {
                        ActionRow(action: action, isChosen: true) { toggle(id) }
                    }
                }
                .onMove { source, destination in
                    chosen.move(fromOffsets: source, toOffset: destination)
                    save()
                }
            } header: {
                Text("On the Deck")
            } footer: {
                Text("Drag to reorder. Shortcuts and scripts on your Mac appear here automatically.")
            }

            let others = model.deck.filter { !chosen.contains($0.id) }
            if !others.isEmpty {
                Section("More Actions") {
                    ForEach(others) { action in
                        ActionRow(action: action, isChosen: false) { toggle(action.id) }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .onAppear {
            chosen = widget.options.deckActions ?? model.deck.map(\.id)
        }
    }

    private func action(_ id: String) -> DeckAction? {
        model.deck.first { $0.id == id }
    }

    private func toggle(_ id: String) {
        withAnimation {
            if let index = chosen.firstIndex(of: id) { chosen.remove(at: index) } else { chosen.append(id) }
        }
        save()
    }

    private func save() {
        var options = widget.options
        options.deckActions = chosen
        store.setOptions(options, for: widget.id)
    }
}

private struct ActionRow: View {
    let action: DeckAction
    let isChosen: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: toggle) {
                Image(systemName: isChosen ? "minus.circle.fill" : "plus.circle.fill")
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(isChosen ? .red : .green)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isChosen ? "Remove \(action.title)" : "Add \(action.title)")

            Image(systemName: action.symbol)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            Text(action.title)
            Spacer()
            Text(kindLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var kindLabel: LocalizedStringKey {
        switch action.kind {
        case .builtIn: "Built-in"
        case .shortcut: "Shortcut"
        case .script: "Script"
        }
    }
}

/// Give the trackpad's extra gestures a job: any Deck action, including every Shortcut.
private struct TrackpadConfiguration: View {
    @Environment(PadModel.self) private var model
    @Environment(DashboardStore.self) private var store
    let widget: DashboardWidget

    var body: some View {
        Form {
            Section {
                ForEach(TrackpadGesture.allCases) { gesture in
                    Picker(selection: binding(for: gesture)) {
                        Text("Nothing").tag(String?.none)
                        ForEach(model.deck) { action in
                            Label(action.title, systemImage: action.symbol).tag(Optional(action.id))
                        }
                    } label: {
                        Label(gesture.title, systemImage: gesture.symbol)
                    }
                }
            } header: {
                Text("Gestures")
            } footer: {
                Text("Run a Shortcut, lock your Mac or anything else on the Deck with a tap of three or four fingers.")
            }
        }
    }

    private func binding(for gesture: TrackpadGesture) -> Binding<String?> {
        Binding {
            store.widget(widget.id)?.options.gestureActions[gesture.rawValue]
        } set: { id in
            var options = store.widget(widget.id)?.options ?? widget.options
            options.gestureActions[gesture.rawValue] = id
            store.setOptions(options, for: widget.id)
        }
    }
}
