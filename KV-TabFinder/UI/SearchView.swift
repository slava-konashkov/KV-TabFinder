import SwiftUI
import AppKit

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var tabs: [Tab] = []
    @Published private(set) var failures: [TabFetchFailure] = []
    @Published var selectedIndex: Int = 0
    /// Bumped only by keyboard navigation so the list scrolls the new
    /// selection into view. Hover changes `selectedIndex` without
    /// bumping this, so the list doesn't jump under the mouse.
    @Published private(set) var scrollRevision: Int = 0

    var results: [SearchResult] {
        SearchResult.rank(tabs: tabs, query: query)
    }

    func load(result: TabFetchResult) {
        tabs = result.tabs
        failures = result.failures
        selectedIndex = 0
        scrollRevision &+= 1
    }

    func moveDown() {
        guard !results.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, results.count - 1)
        scrollRevision &+= 1
    }

    func moveUp() {
        guard !results.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
        scrollRevision &+= 1
    }

    func selectByHover(_ idx: Int) {
        guard results.indices.contains(idx) else { return }
        selectedIndex = idx
        // Intentionally do NOT bump scrollRevision — hover must not scroll.
    }

    func resetToTop() {
        selectedIndex = 0
        scrollRevision &+= 1
    }

    func selected() -> SearchResult? {
        let r = results
        guard r.indices.contains(selectedIndex) else { return nil }
        return r[selectedIndex]
    }
}

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    let onActivate: (Tab) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))

                SpotlightTextField(
                    text: $viewModel.query,
                    placeholder: "Search tabs…"
                )
                .frame(height: 22)
                .onChange(of: viewModel.query) { _ in
                    viewModel.resetToTop()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            if !viewModel.failures.isEmpty {
                FailuresBanner(failures: viewModel.failures)
            }

            // Results list
            if viewModel.results.isEmpty {
                EmptyStateView(hasQuery: !viewModel.query.isEmpty)
            } else {
                ResultsList(
                    results: viewModel.results,
                    selectedIndex: viewModel.selectedIndex,
                    scrollRevision: viewModel.scrollRevision,
                    onSelect: { idx in
                        viewModel.selectByHover(idx)
                        if let s = viewModel.selected() { onActivate(s.tab) }
                    },
                    onHover: { idx in
                        viewModel.selectByHover(idx)
                    }
                )
            }
        }
        .frame(width: 640, height: 420)
        .background(
            VisualEffectView(material: .hudWindow, blending: .behindWindow)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ResultsList: View {
    let results: [SearchResult]
    let selectedIndex: Int
    let scrollRevision: Int
    let onSelect: (Int) -> Void
    let onHover: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { idx, r in
                        ResultRow(result: r, isSelected: idx == selectedIndex)
                            .onTapGesture { onSelect(idx) }
                            .onHover { hovering in
                                if hovering { onHover(idx) }
                            }
                    }
                }
                .padding(6)
            }
            .onChange(of: scrollRevision) { _ in
                // Scroll by the row's UUID so ForEach's identity and
                // the ScrollViewReader target agree. `anchor: nil` asks
                // SwiftUI for the minimal scroll to make the row
                // visible — works for first and last rows alike,
                // unlike `.center` which silently no-ops at edges.
                guard results.indices.contains(selectedIndex) else { return }
                let targetID = results[selectedIndex].id
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(targetID, anchor: nil)
                }
            }
        }
    }
}

private struct EmptyStateView: View {
    let hasQuery: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: hasQuery ? "magnifyingglass" : "safari")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(.secondary)
            Text(hasQuery ? "No matching tabs" : "No open browser tabs")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FailuresBanner: View {
    let failures: [TabFetchFailure]

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(summary)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
    }

    private var summary: String {
        failures.map { f in
            "\(f.browser.displayName): \(message(for: f.error))"
        }.joined(separator: " · ")
    }

    private func message(for error: TabProviderError) -> String {
        switch error {
        case .notAuthorized:
            return "not authorized (System Settings → Privacy → Automation)"
        case .scriptFailed(_, let m):
            return m
        case .invalidResponse:
            return "invalid AppleScript response"
        }
    }
}

/// Translucent background behind the panel content.
private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

