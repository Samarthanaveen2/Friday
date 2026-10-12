import SwiftUI

/// A box opened full screen: a plain page to edit, an optional reminder, and the talk pill.
struct BoxDetailScreen: View {
    @Binding var title: String
    @Binding var text: String
    var reminder: String?
    var pinned = false
    var color: BoxColor = .white
    var talk: TalkState = .idle
    var onBack: () -> Void = {}
    var onPin: () -> Void = {}
    /// Colour, delete and the rest of the ⋯ menu (reminder and pin go to their own callbacks).
    var onAction: (BoxAction) -> Void = { _ in }
    var onReminder: () -> Void = {}
    var onClearReminder: () -> Void = {}
    var onTalk: () -> Void = {}
    var onCancelTalk: () -> Void = {}
    var onDoneTalk: () -> Void = {}
    @State private var pins = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back")
                Spacer()
                Button {
                    pins += 1
                    onPin()
                } label: {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(pinned ? "Unpin" : "Pin")
                .sensoryFeedback(.selection, trigger: pins)
                Menu {
                    BoxMenuItems(pinned: pinned, color: color) { action in
                        switch action {
                        case .pin: onPin()
                        case .reminder: onReminder()
                        default: onAction(action)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More")
            }
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(Palette.text)
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: 48)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Title", text: $title, axis: .vertical)
                        .scaledFont(28, .bold, relativeTo: .title)
                        .foregroundStyle(Palette.text)
                    reminderChip
                    TextField("Write or talk…", text: $text, axis: .vertical)
                        .scaledFont(17)
                        .lineSpacing(4)
                        .foregroundStyle(Palette.text)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TalkPill(state: talk, onTalk: onTalk, onCancel: onCancelTalk, onDone: onDoneTalk)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(color.fill)
        }
        .background(color.fill.ignoresSafeArea())
    }

    @ViewBuilder private var reminderChip: some View {
        if let reminder {
            HStack(spacing: 8) {
                Button(action: onReminder) {
                    Label(reminder, systemImage: "bell")
                        .scaledFont(14, .medium, relativeTo: .subheadline)
                        .foregroundStyle(Palette.text)
                }
                .buttonStyle(.plain)
                Button(action: onClearReminder) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove reminder")
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Palette.text.opacity(0.06), in: Capsule())
        } else {
            Button(action: onReminder) {
                Label("Add reminder", systemImage: "bell")
                    .scaledFont(14, .medium, relativeTo: .subheadline)
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Palette.text.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
