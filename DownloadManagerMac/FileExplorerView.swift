import SwiftUI

struct FileExplorerView: View {
    @StateObject private var explorer = FileExplorer()
    @State private var selectedItem: FileItem?
    @State private var currentDirectory: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Path bar
            HStack(spacing: 4) {
                Button(action: { goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentDirectory == nil)

                if let dir = currentDirectory {
                    Text(dir.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            // File list
            List(
                explorer.contents(of: currentDirectory ?? FileUtils.defaultDownloadDirectory),
                selection: $selectedItem
            ) { file in
                FileItemRow(file: file, isSelected: selectedItem?.url == file.url)
                    .onTapGesture {
                        if file.type == .folder {
                            currentDirectory = file.url
                        } else {
                            selectedItem = file
                        }
                    }
            }
            .listStyle(.sidebar)

            // Preview panel
            if let selected = selectedItem, selected.type == .file {
                Divider()
                PreviewPanel(file: selected)
                    .frame(height: 200)
            }
        }
        .onAppear {
            currentDirectory = FileUtils.defaultDownloadDirectory
        }
    }

    private func goBack() {
        if let parent = currentDirectory?.parentDirectory {
            currentDirectory = parent
        } else {
            currentDirectory = nil
        }
    }
}

struct PreviewPanel: View {
    let file: FileItem

    var body: some View {
        VStack {
            HStack {
                Text("预览: \(file.name)")
                    .font(.headline)
                Spacer()
                Button("打开") {
                    NSWorkspace.shared.open(file.url)
                }
            }
            .padding()

            if file.url.pathExtension.lowercased().contains("image")
                || ["jpg", "jpeg", "png", "gif", "heic"].contains(
                    file.url.pathExtension.lowercased())
            {
                Image(nsImage: NSImage(contentsOf: file.url) ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            } else {
                Text("不支持的文件类型预览")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct PathComponent: Hashable {
    let name: String
    let path: URL
}
