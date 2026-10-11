import SwiftUI

/// A box opened full screen: edit the text, set a reminder, or talk to the box.
struct BoxDetailScreen: View {
    @Binding var title: String
    @Binding var text: String
    var reminder: String?
    var pinned = false
    var listening = false
    var onBack: () -> Void = {}
    var onPin: () -> Void = {}
    var onMenu: () -> Void = {}
    var onReminder: () -> Void = {}
    var onClearReminder: () -> Void = {}
    var onTalk: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundIcon(systemName: "chevron.left", label: "Back", action: onBack)
                Spacer()
                RoundIcon(systemName: pinned ? "pin.fill" : "pin", label: pinned ? "Unpin" : "Pin", action: onPin)
                RoundIcon(systemName: "ellipsis", label: "More", action: onMenu)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Title", text: $title, axis: .vertical)
                        .scaledFont(26, .bold, relativeTo: .title)
                        .foregroundStyle(Palette.text)
                    reminderChip
                    TextField("Write or talk…", text: $text, axis: .vertical)
                        .scaledFont(17)
                        .lineSpacing(4)
                        .foregroundStyle(Palette.text)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onTalk) {
                    HStack(spacing: 10) {
                        Image(systemName: listening ? "waveform" : "mic.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .symbolEffect(.variableColor.iterative, isActive: listening)
                        Text(listening ? "Listening… tap when done" : "Talk to this box")
                            .scaledFont(16, .semibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 54)
                    .background(Palette.accent, in: Capsule())
                    .shadow(color: Palette.accent.opacity(0.28), radius: 14, y: 6)
                }
                .buttonStyle(PressScale())
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Palette.card.opacity(0.001))
        }
        .background(Palette.card.ignoresSafeArea())
    }

    @ViewBuilder private var reminderChip: some View {
        if let reminder {
            HStack(spacing: 6) {
                Button(action: onReminder) {
                    Label(reminder, systemImage: "bell.fill")
                        .scaledFont(14, .semibold, relativeTo: .subheadline)
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
                Button(action: onClearReminder) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove reminder")
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Palette.changeTint, in: Capsule())
        } else {
            Button(action: onReminder) {
                Label("Add reminder", systemImage: "bell")
                    .scaledFont(14, .medium, relativeTo: .subheadline)
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Palette.raised, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
