import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

@main
struct FridayLiveBundle: WidgetBundle {
    var body: some Widget {
        ProbeLiveActivity()
        StartProbeControl()
    }
}

/// Lock screen + Dynamic Island while a session is running.
struct ProbeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProbeAttributes.self) { context in
            HStack {
                Image(systemName: "mic.fill")
                Text("Friday is listening · \(context.state.seconds) s")
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("Friday · \(context.state.seconds) s")
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
            } compactTrailing: {
                Text("\(context.state.seconds)s")
            } minimal: {
                Image(systemName: "mic.fill")
            }
        }
    }
}

/// Control Center button (can also be put on the Action button).
struct StartProbeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.samarth.friday.probe") {
            ControlWidgetButton(action: StartProbeIntent()) {
                Label("Friday", systemImage: "mic.fill")
            }
        }
        .displayName("Friday mic test")
    }
}
