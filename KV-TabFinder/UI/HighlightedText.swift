import SwiftUI

struct HighlightedText: View {
    let text: String
    let highlights: [Int]
    let font: Font
    let baseColor: Color
    let highlightColor: Color

    init(
        _ text: String,
        highlights: [Int],
        font: Font = .body,
        baseColor: Color = .primary,
        highlightColor: Color = .accentColor
    ) {
        self.text = text
        self.highlights = highlights
        self.font = font
        self.baseColor = baseColor
        self.highlightColor = highlightColor
    }

    var body: some View {
        Text(buildAttributed())
            .font(font)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private func buildAttributed() -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = baseColor
        let highlightSet = Set(highlights)
        let chars = Array(text)
        var cursor = result.startIndex
        for i in 0..<chars.count {
            let next = result.index(afterCharacter: cursor)
            if highlightSet.contains(i) {
                result[cursor..<next].foregroundColor = highlightColor
                result[cursor..<next].font = .system(.body, design: .default).bold()
            }
            cursor = next
        }
        return result
    }
}

private extension AttributedString {
    func index(afterCharacter i: AttributedString.Index) -> AttributedString.Index {
        return characters.index(after: i)
    }
}
