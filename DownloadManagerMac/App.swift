import SwiftUI

@main
struct DownloadManagerMacApp: App {
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 900, minHeight: 600)
                .environmentObject(downloadManager)
                .environmentObject(settingsManager)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
