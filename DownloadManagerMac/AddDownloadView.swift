import SwiftUI

struct AddDownloadView: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var urlString = ""
    @State private var fileName = ""
    @State private var savePath = FileUtils.defaultDownloadDirectory.path
    @State private var isM3U8 = false

    var body: some View {
        VStack(spacing: 20) {
            Text("添加下载任务")
                .font(.title)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Text("下载链接")
                TextField("请输入下载链接", text: $urlString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("文件名称（可选）")
                TextField("自定义文件名称", text: $fileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("保存路径")
                HStack {
                    TextField("", text: $savePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true)
                    Button("浏览") {
                        let openPanel = NSOpenPanel()
                        openPanel.canChooseFiles = false
                        openPanel.canChooseDirectories = true
                        openPanel.allowsMultipleSelection = false
                        if openPanel.runModal() == .OK {
                            if let url = openPanel.url {
                                savePath = url.path
                            }
                        }
                    }
                }
            }

            Toggle("M3U8 视频下载", isOn: $isM3U8)

            HStack {
                Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                }

                Button("添加") {
                    if let url = URL(string: urlString) {
                        let destinationURL = URL(fileURLWithPath: savePath).appendingPathComponent(
                            fileName.isEmpty ? url.lastPathComponent : fileName)
                        if isM3U8 {
                            DownloadManager.shared.startM3U8Download(
                                url: url, destinationURL: destinationURL)
                        } else {
                            DownloadManager.shared.startDownload(
                                url: url, destinationURL: destinationURL)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(urlString.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
