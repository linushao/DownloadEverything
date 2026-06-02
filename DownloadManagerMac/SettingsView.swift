import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var segmentLimitText = "0"

    var body: some View {
        VStack(spacing: 30) {
            Text("设置")
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("下载地址")
                        .font(.headline)
                    HStack {
                        TextField("", text: $settingsManager.downloadPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(true)
                            .frame(minWidth: 300)
                        Button("浏览") {
                            let openPanel = NSOpenPanel()
                            openPanel.canChooseFiles = false
                            openPanel.canChooseDirectories = true
                            openPanel.allowsMultipleSelection = false
                            if openPanel.runModal() == .OK {
                                if let url = openPanel.url {
                                    settingsManager.downloadPath = url.path
                                }
                            }
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("M3U8 切片限制")
                        .font(.headline)
                    HStack {
                        TextField("输入切片数量", text: $segmentLimitText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 150)
                            .onChange(of: segmentLimitText) { newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    segmentLimitText = filtered
                                }
                                if let value = Int(segmentLimitText), value >= 0 {
                                    settingsManager.m3u8SegmentLimit = value
                                } else if segmentLimitText.isEmpty {
                                    settingsManager.m3u8SegmentLimit = 0
                                }
                            }
                        Text("设置为 0 表示下载所有切片")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            Spacer()
        }
        .padding()
        .onAppear {
            segmentLimitText = String(settingsManager.m3u8SegmentLimit)
        }
    }
}
