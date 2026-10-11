import SwiftUI

/// Keys and dictionary. Keys are pasted here on the phone and kept in the Keychain.
struct SettingsView: View {
    @State private var groq = Keys.get(.groq) ?? ""
    @State private var gemini = Keys.get(.gemini) ?? ""
    @State private var words = (UserDefaults.standard.stringArray(forKey: "dict.words") ?? []).joined(separator: ", ")
    @State private var saved = false

    var body: some View {
        Form {
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
        }
        .navigationTitle("Settings")
    }
}
