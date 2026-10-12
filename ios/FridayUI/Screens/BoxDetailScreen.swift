import SwiftUI

/// A box opened full screen: a plain page to edit, an optional reminder, and the talk pill.
struct BoxDetailScreen: View {
    @Binding var title: String
    @Binding var text: String
    var reminder: String?
    var pinned = false
    var talk: TalkState = .idle
    var onBack: () -> Void = {}
    var onPin: () -> Void = {}
    var onMenu: () -> Void = {}
    var onReminder: () -> Void = {}
    var onClearReminder: () -> Void = {}
    var onTalk: () -> Void = {}
    var onCancelTalk: () -> Void = {}
    var onDoneTalk: () -> Void = {}
    @State private var pins = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 22) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                        .frame(width: 32, height: 44, alignment: .leading)
                }
                .accessibilityLabel("Back")
                Spacer()
                Button {
                    pins += 1
                    onPin()
                } label: {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                }
                .accessibilityLabel(pinned ? "Unpin" : "Pin")
                .sensoryFeedback(.selection, trigger: pins)
                Button(action: onMenu) { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("More")
            }
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(Palette.text)
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
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
                .background(Palette.background)
        }
        .background(Palette.background.ignoresSafeArea())
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
            .background(Palette.card, in: Capsule())
        } else {
            Button(action: onReminder) {
                Label("Add reminder", systemImage: "bell")
                    .scaledFont(14, .medium, relativeTo: .subheadline)
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Palette.card, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
