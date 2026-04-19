import SwiftUI

@main
struct ReadItAllApp: App {
    @AppStorage("readcomics.appearance") private var themePreferenceRaw = AppThemePreference.system.rawValue
    @StateObject private var libraryStore: ComicLibraryStore
    @StateObject private var readerViewModel: ReaderViewModel

    init() {
        let libraryStore = ComicLibraryStore()
        _libraryStore = StateObject(wrappedValue: libraryStore)
        _readerViewModel = StateObject(wrappedValue: ReaderViewModel(libraryStore: libraryStore))
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(libraryStore)
                .environmentObject(readerViewModel)
                .preferredColorScheme(currentThemePreference.colorScheme)
        }
    }

    private var currentThemePreference: AppThemePreference {
        AppThemePreference(rawValue: themePreferenceRaw) ?? .system
    }
}
