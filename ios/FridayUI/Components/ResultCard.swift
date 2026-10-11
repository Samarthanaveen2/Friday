import SwiftUI

/// The only place the app "says" something, and only when you asked (PLAN §3).
struct ResultCardModel: Equatable {
    enum Kind: Equatable {
        /// A 1–3 line answer (web, email summary), with the source site.
        case answer(text: String, source: String?)
        /// Something ready to send; one tap does it.
        case ready(title: String, preview: String, button: String, systemImage: String)
        /// A name or item that matched more than one thing.
        case choice(question: String, options: [String])
    }

    var kind: Kind
}

struct ResultCard: View {
    let model: ResultCardModel
    var onClose: () -> Void = {}
    var onPrimary: () -> Void = {}
    var onChoose: (Int) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.kind {
            case let .answer(text, source):
                Text(text)
                    .scaledFont(16)
                    .foregroundStyle(Palette.text)
                    .lineLimit(3)
                    .padding(.trailing, 28)
                if let source {
                    Label(source, systemImage: "globe")
                        .scaledFont(12, .medium, relativeTo: .caption)
                        .foregroundStyle(Palette.secondary)
                }
            case let .ready(title, preview, button, systemImage):
                Text(title)
                    .scaledFont(13, .semibold, relativeTo: .footnote)
                    .foregroundStyle(Palette.secondary)
                Text(preview)
                    .scaledFont(16)
                    .foregroundStyle(Palette.text)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Palette.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                CapsuleButton(title: button, systemImage: systemImage, action: onPrimary)
            case let .choice(question, options):
                Text(question)
                    .scaledFont(16, .semibold)
                    .foregroundStyle(Palette.text)
                    .padding(.trailing, 28)
                VStack(spacing: 8) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        CapsuleButton(title: option, style: .secondary) { onChoose(index) }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.secondary)
                    .frame(width: 26, height: 26)
                    .background(Palette.raised, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("Close")
        }
        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
    }
}
