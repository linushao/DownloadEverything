import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var segmentLimitText = "0"
    @State private var showSuccessMessage = false

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

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("User-Agent 设置")
                            .font(.headline)
                        if showSuccessMessage {
                            Text("✓ 已生效")
                                .foregroundColor(.green)
                                .font(.footnote)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        UserAgentSection(title: "系统默认", options: [UserAgentManager.shared.defaultOption])
                        UserAgentSection(title: "iPhone", options: UserAgentManager.shared.iphoneOptions)
                        UserAgentSection(title: "Android", options: UserAgentManager.shared.androidOptions)
                        UserAgentSection(title: "桌面端", options: UserAgentManager.shared.desktopOptions)
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

    private func selectUserAgent(_ option: UserAgentOption) {
        settingsManager.userAgentId = option.id
        showSuccessMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSuccessMessage = false
        }
    }

    private func UserAgentSection(title: String, options: [UserAgentOption]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            ForEach(options) { option in
                Button(action: { selectUserAgent(option) }) {
                    HStack(spacing: 8) {
                        Image(systemName: settingsManager.userAgentId == option.id ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(settingsManager.userAgentId == option.id ? .accentColor : .secondary)
                        Text(option.name)
                            .foregroundColor(.primary)
                    }
                    .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
