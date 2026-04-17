import SwiftUI

struct ResultRow: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            BrowserIcon(browser: result.tab.browser)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                HighlightedText(
                    result.tab.title.isEmpty ? "(untitled)" : result.tab.title,
                    highlights: result.matchIndices,
                    font: .system(size: 13, weight: .medium),
                    baseColor: isSelected ? .white : .primary,
                    highlightColor: isSelected ? .white : .accentColor
                )
                Text(result.tab.url)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Text(result.tab.browser.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected
                              ? Color.white.opacity(0.2)
                              : Color.secondary.opacity(0.12))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

private struct BrowserIcon: View {
    let browser: BrowserKind

    var body: some View {
        if let nsImage = browser.icon {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "globe")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.secondary)
        }
    }
}
