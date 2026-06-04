import SwiftUI

struct MainView: View {
    @EnvironmentObject var downloadManager: DownloadManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0
    @State private var showAddDownload = false

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                Button(action: { selectedTab = 0 }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("下载管理")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectedTab == 0 ? Color.accentColor : Color.clear)
                    .foregroundColor(selectedTab == 0 ? .white : .primary)
                }

                Button(action: { selectedTab = 1 }) {
                    HStack {
                        Image(systemName: "folder")
                        Text("文件管理")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectedTab == 1 ? Color.accentColor : Color.clear)
                    .foregroundColor(selectedTab == 1 ? .white : .primary)
                }

                Button(action: { selectedTab = 3 }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("网页浏览")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectedTab == 3 ? Color.accentColor : Color.clear)
                    .foregroundColor(selectedTab == 3 ? .white : .primary)
                }

                Divider()

                Button(action: { showAddDownload = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("添加下载")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: { selectedTab = 2 }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("设置")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectedTab == 2 ? Color.accentColor : Color.clear)
                    .foregroundColor(selectedTab == 2 ? .white : .primary)
                }

                Spacer()
            }
            .frame(width: 180)
            .background(Color(NSColor.controlBackgroundColor))

            // Main content
            Divider()

            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text(tabTitle)
                        .font(.title)
                        .fontWeight(.bold)

                    Spacer()

                    if selectedTab == 0 {
                        Button(action: { downloadManager.pauseAll() }) {
                            Image(systemName: "pause")
                        }
                        Button(action: { downloadManager.resumeAll() }) {
                            Image(systemName: "play")
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

                // Content
                if selectedTab == 0 {
                    DownloadListView()
                } else if selectedTab == 1 {
                    FileExplorerView()
                } else if selectedTab == 3 {
                    WebView()
                } else {
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showAddDownload) {
            AddDownloadView()
        }
        .onChange(of: settingsManager.m3u8SegmentLimit) { newValue in
            downloadManager.m3u8SegmentLimit = newValue
        }
    }

    private var tabTitle: String {
        switch selectedTab {
        case 0:
            return "下载管理"
        case 1:
            return "文件管理"
        case 2:
            return "设置"
        case 3:
            return "网页浏览"
        default:
            return ""
        }
    }
}
