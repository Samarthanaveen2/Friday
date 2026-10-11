import SwiftUI

/// After the keyboard opens Friday to start a session: the mic is on, now swipe back.
/// iOS gives apps no way to return you automatically (PLAN §2.3), so this teaches the gesture.
struct SwipeBackView: View {
    var onDismiss: () -> Void = {}
    @State private var slide = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
                Text("Friday is on")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                Text("Swipe right along the bottom edge\nto go back, then tap 🎤 again.")
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)

            // A ghost finger sliding along the home indicator.
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25)).frame(width: 140, height: 5)
                Circle()
                    .fill(.white)
                    .frame(width: 30, height: 30)
                    .shadow(color: .white.opacity(0.6), radius: 10)
                    .offset(x: slide ? 120 : -10, y: 0)
                    .opacity(slide ? 0 : 1)
            }
            .frame(width: 140)
            .padding(.bottom, 12)
            .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false)) { slide = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Friday is on. Swipe right along the bottom edge to go back, then tap the mic again.")
    }
}
