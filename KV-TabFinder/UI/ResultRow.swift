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
                    highlights: result.matchField == .title ? result.matchIndices : [],
                    font: .system(size: 13, weight: .medium),
                    baseColor: isSelected ? .white : .primary,
                    highlightColor: isSelected ? .white : .accentColor
                )
                HighlightedText(
                    result.tab.url,
                    highlights: result.matchField == .url ? result.matchIndices : [],
                    font: .system(size: 11),
                    baseColor: isSelected ? .white.opacity(0.85) : .secondary,
                    highlightColor: isSelected ? .white : .accentColor,
                    truncation: .middle
                )
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                BrowserBadge(
                    text: result.tab.browser.displayName,
                    isSelected: isSelected
                )
                if let hint = result.tab.accountHint {
                    BrowserBadge(
                        text: hint,
                        isSelected: isSelected,
                        subtle: true,
                        tint: AccountColor.color(for: hint)
                    )
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
    var tint: Color? = nil

    var body: some View {
        Text(text)
            .font(.system(size: subtle ? 9 : 10, weight: .medium))
            .foregroundColor(textColor)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(backgroundFill)
            )
    }

    private var backgroundFill: Color {
        if let tint {
            return isSelected ? tint.opacity(0.45) : tint.opacity(0.22)
        }
        return isSelected
            ? Color.white.opacity(subtle ? 0.12 : 0.2)
            : Color.secondary.opacity(subtle ? 0.08 : 0.12)
    }

    private var textColor: Color {
        isSelected ? .white.opacity(subtle ? 0.9 : 0.95) : .secondary
    }
}

/// Deterministic, muted colour per account string so the same profile
/// always renders with the same tint across launches.
enum AccountColor {
    // Low-saturation, medium-brightness palette. Readable on both light
    // and dark chrome-panel backgrounds; no neon.
    private static let palette: [Color] = [
        Color(red: 0.42, green: 0.55, blue: 0.72),  // slate blue
        Color(red: 0.50, green: 0.65, blue: 0.52),  // sage green
        Color(red: 0.78, green: 0.60, blue: 0.42),  // sand
        Color(red: 0.62, green: 0.52, blue: 0.72),  // dusty lilac
        Color(red: 0.78, green: 0.52, blue: 0.58),  // muted rose
        Color(red: 0.42, green: 0.62, blue: 0.63),  // muted teal
        Color(red: 0.50, green: 0.54, blue: 0.70),  // steel
        Color(red: 0.72, green: 0.48, blue: 0.45),  // terracotta
        Color(red: 0.70, green: 0.65, blue: 0.45),  // khaki
        Color(red: 0.52, green: 0.60, blue: 0.48),  // olive-sage
    ]

    static func color(for key: String) -> Color {
        var hash: UInt64 = 5381
        for byte in key.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return palette[Int(hash % UInt64(palette.count))]
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
