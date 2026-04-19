import SwiftUI

struct AppSettingsView: View {
    @AppStorage("readcomics.appearance") private var themePreferenceRaw = AppThemePreference.system.rawValue

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $themePreferenceRaw) {
                    ForEach(AppThemePreference.allCases) { preference in
                        Text(preference.title)
                            .tag(preference.rawValue)
                    }
                }
                .pickerStyle(.inline)

                Text("System follows the iPhone or iPad appearance setting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("App") {
                    Text("Read Comics")
                }

                LabeledContent("Version") {
                    Text(versionDescription)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionDescription: String {
        let shortVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0.0"
        let buildNumber = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "1"

        return "\(shortVersion) (\(buildNumber))"
    }
}
