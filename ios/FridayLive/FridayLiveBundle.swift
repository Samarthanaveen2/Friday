import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct FridayLiveBundle: WidgetBundle {
    var body: some Widget {
        FridayLiveActivity()
        StartFridayControl()
    }
}

/// "Friday on" in the Dynamic Island and on the Lock Screen while a session runs.
struct FridayLiveActivity: Widget {
    private let accent = Color(red: 0.62, green: 0.64, blue: 1.0)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FridayActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
                Text("Friday on")
                    .font(.headline)
                Spacer()
                Text(context.state.startedAt, style: .timer)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform").foregroundStyle(accent).padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Friday on").font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 52)
                }
            } compactLeading: {
                Image(systemName: "waveform").foregroundStyle(accent)
            } compactTrailing: {
                Text("On").font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: "waveform").foregroundStyle(accent)
            }
        }
    }
}

/// Control Center / Lock Screen / Action button control.
struct StartFridayControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.samarth.friday.start") {
            ControlWidgetButton(action: StartFridayIntent()) {
                Label("Start Friday", systemImage: "waveform")
            }
        }
        .displayName("Start Friday")
        .description("Turns on Friday's mic.")
    }
}
