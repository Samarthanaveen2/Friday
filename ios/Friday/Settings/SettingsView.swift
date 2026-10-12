import SwiftUI
import UIKit

/// Keys and dictionary. Keys are pasted here on the phone and kept in the Keychain.
struct SettingsView: View {
    /// Set when opened from Home, so the Setup check can be reached from here.
    var probe: ProbeModel?
    @Environment(\.dismiss) private var dismiss
    @State private var groq = Keys.get(.groq) ?? ""
    @State private var gemini = Keys.get(.gemini) ?? ""
    @State private var words = (UserDefaults.standard.stringArray(forKey: "dict.words") ?? []).joined(separator: ", ")
    @State private var saved = false

    var body: some View {
        Form {
            UsageSection()

            CalendarSection()

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Talk from the Lock Screen", systemImage: "mic.fill").font(.headline)
                    Text("1. Press and hold the Lock Screen → Customize → Lock Screen\n2. Tap − on the camera button, then +\n3. Pick Friday → Talk to Friday\n4. Press and hold it: Friday opens, already listening.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("You can add the same button to Control Center.")
            }

            Section {
                SecureField("Groq key (gsk_…)", text: $groq)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Gemini key (optional)", text: $gemini)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(saved ? "Saved" : "Save keys") {
                    Keys.set(.groq, groq)
                    Keys.set(.gemini, gemini)
                    Haptics.success()
                    withAnimation(Motion.fade) { saved = true }
                    DictationPipeline.warm()
                }
            } header: {
                Text("Free cloud keys")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Without a key Friday uses the phone's own speech and AI. With a Groq key it's faster and more accurate.")
                    Link("Get a free Groq key", destination: URL(string: "https://console.groq.com/keys")!)
                    Link("Get a free Gemini key", destination: URL(string: "https://aistudio.google.com/apikey")!)
                }
            }

            Section {
                TextField("Samartha, Kharagpur, Arjun", text: $words, axis: .vertical)
                    .onChange(of: words) { _, value in
                        let list = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        UserDefaults.standard.set(list, forKey: "dict.words")
                    }
            } header: {
                Text("Dictionary")
            } footer: {
                Text("Names and words Friday must always spell exactly. Separate with commas.")
            }

            if let probe {
                Section {
                    NavigationLink { ProbeView(model: probe, embedded: true) } label: {
                        Label("Setup check", systemImage: "checklist")
                    }
                } footer: {
                    Text("Keyboard, mic and Action button checks, the dictation test and Copy steps.")
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            if probe != nil {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

/// Calendar access: Friday reads your calendars and adds events to a "Friday" calendar.
private struct CalendarSection: View {
    @State private var calendar = CalendarService.shared

    var body: some View {
        Section {
            HStack {
                Label("Calendar", systemImage: "calendar")
                Spacer()
                if calendar.authorized {
                    Text("On").foregroundStyle(.secondary)
                } else if CalendarService.denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } else {
                    Button("Allow") { Task { _ = await calendar.requestAccess() } }
                }
            }
        } footer: {
            Text("Friday reads your calendars (Google too, if it's added in iOS Settings → Calendar) so it knows your schedule, adds new meetings to a “Friday” calendar, and can move or cancel events when you ask.")
        }
    }
}
