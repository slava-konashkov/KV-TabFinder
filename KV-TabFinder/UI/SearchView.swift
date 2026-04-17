import SwiftUI
import AppKit

/// Paired (index, nonce) so the scroll handler receives both atomically.
/// Relying on a separate `@Published var scrollRevision` + reading
/// `selectedIndex` inside the onChange closure was racy: SwiftUI fired
/// the closure with a captured `selectedIndex` that was still one
/// step behind the new revision.
struct ScrollTrigger: Equatable {
    var index: Int
    var nonce: Int
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var tabs: [Tab] = []
    @Published private(set) var failures: [TabFetchFailure] = []
    @Published var selectedIndex: Int = 0
    /// Bumped only by keyboard navigation (and only when the selection
    /// actually moved). Hover does NOT bump so the list doesn't jump
    /// under the mouse. The `index` field carries the authoritative
    /// scroll target — read it from the trigger, not from
    /// `selectedIndex` which may lag in closure captures.
    @Published private(set) var scrollTrigger = ScrollTrigger(index: 0, nonce: 0)

    var results: [SearchResult] {
        SearchResult.rank(tabs: tabs, query: query)
    }

    func load(result: TabFetchResult) {
        tabs = result.tabs
        failures = result.failures
        selectedIndex = 0
        scrollTrigger = ScrollTrigger(index: 0, nonce: scrollTrigger.nonce &+ 1)
    }

    func moveDown() {
        guard !results.isEmpty else {
            Log.panel.notice("moveDown ignored — results empty")
            return
        }
        let next = min(selectedIndex + 1, results.count - 1)
        guard next != selectedIndex else {
            Log.panel.notice("moveDown NOOP idx=\(self.selectedIndex) count=\(self.results.count)")
            return
        }
        let prev = selectedIndex
        selectedIndex = next
        scrollTrigger = ScrollTrigger(index: next, nonce: scrollTrigger.nonce &+ 1)
        Log.panel.notice("moveDown \(prev)→\(next) nonce=\(self.scrollTrigger.nonce)")
    }

    func moveUp() {
        guard !results.isEmpty else {
            Log.panel.notice("moveUp ignored — results empty")
            return
        }
        let next = max(selectedIndex - 1, 0)
        guard next != selectedIndex else {
            Log.panel.notice("moveUp NOOP idx=\(self.selectedIndex)")
            return
        }
        let prev = selectedIndex
        selectedIndex = next
        scrollTrigger = ScrollTrigger(index: next, nonce: scrollTrigger.nonce &+ 1)
        Log.panel.notice("moveUp \(prev)→\(next) nonce=\(self.scrollTrigger.nonce)")
    }

    func selectByHover(_ idx: Int) {
        guard results.indices.contains(idx) else { return }
        selectedIndex = idx
        // Intentionally do NOT bump scrollTrigger — hover must not scroll.
    }

    func resetToTop() {
        selectedIndex = 0
        scrollTrigger = ScrollTrigger(index: 0, nonce: scrollTrigger.nonce &+ 1)
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
                    scrollTrigger: viewModel.scrollTrigger,
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
    let scrollTrigger: ScrollTrigger
    let onSelect: (Int) -> Void
    let onHover: (Int) -> Void

    var body: some View {
        // Real buffer views (not `.padding`) above and below the
        // ScrollView, so its viewport ends exactly at the buffer edge.
        // The selection highlight is then never clipped by the panel
        // corners.
        VStack(spacing: 0) {
            Color.clear.frame(height: 6)
            ScrollViewReader { proxy in
                ScrollView {
                    // Plain VStack (not Lazy) so every row has a known
                    // layout frame from the start — LazyVStack breaks
                    // `scrollTo` at the list edges.
                    VStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { idx, r in
                            ResultRow(result: r, isSelected: idx == selectedIndex)
                                .onTapGesture { onSelect(idx) }
                                .onHover { hovering in
                                    if hovering { onHover(idx) }
                                }
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .onChange(of: scrollTrigger) { trigger in
                    // Use `trigger.index`, NOT the outer `selectedIndex`
                    // — the struct guarantees index and nonce travel
                    // together through the same @Published update.
                    guard results.indices.contains(trigger.index) else {
                        Log.panel.notice("scroll onChange nonce=\(trigger.nonce) — idx=\(trigger.index) out of bounds (count=\(results.count))")
                        return
                    }
                    let targetID = results[trigger.index].id
                    Log.panel.notice("scroll onChange nonce=\(trigger.nonce) → scrollTo idx=\(trigger.index) id=\(targetID, privacy: .public)")
                    proxy.scrollTo(targetID, anchor: nil)
                }
            }
            Color.clear.frame(height: 6)
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

