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

            VStack(alignment: .trailing, spacing: 2) {
                BrowserBadge(
                    text: result.tab.browser.displayName,
                    isSelected: isSelected
                )
                if let hint = result.tab.accountHint {
                    BrowserBadge(text: hint, isSelected: isSelected, subtle: true)
                }
            }
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

private struct BrowserBadge: View {
    let text: String
    let isSelected: Bool
    var subtle: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: subtle ? 9 : 10, weight: .medium))
            .foregroundColor(isSelected ? .white.opacity(subtle ? 0.75 : 0.9) : .secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected
                          ? Color.white.opacity(subtle ? 0.12 : 0.2)
                          : Color.secondary.opacity(subtle ? 0.08 : 0.12))
            )
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
