import SwiftUI

/// What the Friday Keyboard shows (PLAN §2.2). The keyboard controller owns the logic.
struct KeyboardModel: Equatable {
    enum Mode: Equatable {
        case idle
        case recording(seconds: Int)
        case working
    }

    enum Strip: Equatable {
        case info(String)
        case warning(String)
        case pasteLast
    }

    var mode: Mode = .idle
    var tone = "As said"
    var levels: [CGFloat] = []
    var strip: Strip?
    var symbolsPage = 0
}

struct KeyboardActions {
    var key: (String) -> Void = { _ in }
    var delete: () -> Void = {}
    var space: () -> Void = {}
    var returnKey: () -> Void = {}
    var nextKeyboard: () -> Void = {}
    var toggleSymbols: () -> Void = {}
    var mic: () -> Void = {}
    var cancel: () -> Void = {}
    var done: () -> Void = {}
    var tone: () -> Void = {}
    var menu: () -> Void = {}
    var pasteLast: () -> Void = {}
}

struct KeyboardView: View {
    let model: KeyboardModel
    var actions = KeyboardActions()

    static let height: CGFloat = 262

    var body: some View {
        ZStack {
            switch model.mode {
            case .idle:
                VStack(spacing: 0) {
                    topBar
                    pad
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .recording, .working:
                recording
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .frame(height: KeyboardView.height)
        .animation(Motion.fade, value: model.mode == .idle)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 0) {
            Button(action: actions.menu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Palette.keyText)
                    .frame(width: 48, height: 44)
            }
            .accessibilityLabel("Friday menu")
            Spacer(minLength: 4)
            Button(action: actions.tone) {
                Text(model.tone)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 44)
            }
            .accessibilityLabel("Tone: \(model.tone)")
            Button(action: actions.mic) {
                HStack(spacing: 7) {
                    Image(systemName: "mic.fill")
                    Image(systemName: "waveform")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.onInverse)
                .frame(width: 84, height: 40)
                .background(Palette.inverse, in: Capsule())
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("Dictate")
        }
        .buttonStyle(.plain)
        .overlay { stripView.allowsHitTesting(model.strip == .pasteLast) }
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .frame(height: 52)
    }

    @ViewBuilder private var stripView: some View {
        switch model.strip {
        case .info(let text):
            Text(text).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.secondary)
        case .warning(let text):
            Label(text, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.secondary)
        case .pasteLast:
            Button(action: actions.pasteLast) {
                Label("Paste last", systemImage: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.keyText)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Palette.key, in: Capsule())
            }
            .buttonStyle(.plain)
        case nil:
            EmptyView()
        }
    }

    // MARK: Number and symbol pad

    private var rows: [[String]] {
        model.symbolsPage == 0
            ? [["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
               ["-", "/", ":", ";", "(", ")", "₹", "&", "@", "\""],
               [".", ",", "?", "!", "'"]]
            : [["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
               ["_", "\\", "|", "~", "<", ">", "€", "£", "$", "•"],
               [".", ",", "?", "!", "'"]]
    }

    private var pad: some View {
        GeometryReader { geo in
            let gap: CGFloat = 6
            let unit = (geo.size.width - 6 - gap * 9) / 10
            VStack(spacing: 11) {
                charRow(rows[0], width: unit, gap: gap)
                charRow(rows[1], width: unit, gap: gap)
                HStack(spacing: gap) {
                    Key(label: model.symbolsPage == 0 ? "#+=" : "123", font: 16, action: actions.toggleSymbols)
                        .frame(width: unit * 1.35)
                    Spacer(minLength: 0)
                    HStack(spacing: gap) {
                        ForEach(rows[2], id: \.self) { char in
                            Key(label: char, font: 22) { actions.key(char) }
                                .frame(width: unit * 1.3)
                        }
                    }
                    Spacer(minLength: 0)
                    Key(systemImage: "delete.left", action: actions.delete)
                        .frame(width: unit * 1.35)
                        .accessibilityLabel("Delete")
                }
                HStack(spacing: gap) {
                    Key(label: "ABC", font: 16, action: actions.nextKeyboard)
                        .frame(width: unit * 2.5 + gap * 1.5)
                    Key(label: "Friday", font: 16, action: actions.space)
                        .accessibilityLabel("Space")
                    Key(systemImage: "return.left", action: actions.returnKey)
                        .frame(width: unit * 2.5 + gap * 1.5)
                        .accessibilityLabel("Return")
                }
            }
            .padding(.horizontal, 3)
        }
        .frame(height: 4 * 42 + 3 * 11)
        .padding(.top, 2)
    }

    private func charRow(_ chars: [String], width: CGFloat, gap: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(chars, id: \.self) { char in
                Key(label: char, font: char.first!.isNumber ? 25 : 22) { actions.key(char) }
                    .frame(width: width)
            }
        }
    }

    // MARK: Recording

    private var recording: some View {
        VStack(spacing: 0) {
            Group {
                if case .warning(let text) = model.strip {
                    Text(text)
                } else if case .info(let text) = model.strip {
                    Text(text)
                } else {
                    Text(" ")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette.secondary)
            .frame(height: 44)

            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Button(action: actions.cancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Palette.keyText)
                        .frame(width: 56, height: 56)
                        .background(Palette.key, in: Circle())
                }
                .buttonStyle(PressScale())
                .accessibilityLabel("Cancel")

                Spacer(minLength: 12)
                VStack(spacing: 12) {
                    if model.mode == .working {
                        WorkingDots().frame(height: 56)
                    } else {
                        Waveform(levels: model.levels, height: 56, barWidth: 3.5, color: Palette.keyText)
                    }
                    Text(timeLabel)
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(Palette.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer(minLength: 12)

                Button(action: actions.done) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Palette.onInverse)
                        .frame(width: 72, height: 56)
                        .background(Palette.inverse, in: Capsule())
                }
                .buttonStyle(PressScale())
                .disabled(model.mode == .working)
                .opacity(model.mode == .working ? 0.4 : 1)
                .accessibilityLabel("Done")
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
            Spacer().frame(height: 44)
        }
    }

    private var timeLabel: String {
        if case .recording(let seconds) = model.mode {
            return String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
        return " "
    }
}

/// One key: Apple's shape, colour and shadow; darker while pressed.
struct Key: View {
    var label: String?
    var systemImage: String?
    var font: CGFloat = 22
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 19, weight: .regular))
                } else {
                    Text(label ?? "").font(.system(size: font, weight: .regular))
                }
            }
            .foregroundStyle(Palette.keyText)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(KeyStyle())
    }
}

struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                    .fill(configuration.isPressed ? Palette.keyPressed : Palette.key)
                    .shadow(color: Palette.keyShadow, radius: 0, x: 0, y: 1)
            )
    }
}
