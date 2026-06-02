import SwiftUI

struct MainView: View {
    @EnvironmentObject var downloadManager: DownloadManager
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
                
                Spacer()
            }
            .frame(width: 180)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Main content
            Divider()
            
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text(selectedTab == 0 ? "下载管理" : "文件管理")
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
                } else {
                    FileExplorerView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showAddDownload) {
            AddDownloadView()
        }
    }
}
