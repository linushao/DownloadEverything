import Foundation

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults: UserDefaults = UserDefaults.standard

    private enum Keys: String {
        case downloadPath = "com.downloadapp.downloadPath"
        case m3u8SegmentLimit = "com.downloadapp.m3u8SegmentLimit"
        case userAgentId = "com.downloadapp.userAgentId"
        case lastWebURL = "com.downloadapp.lastWebURL"
    }

    @Published var downloadPath: String {
        didSet {
            defaults.set(downloadPath, forKey: Keys.downloadPath.rawValue)
        }
    }

    @Published var m3u8SegmentLimit: Int {
        didSet {
            defaults.set(m3u8SegmentLimit, forKey: Keys.m3u8SegmentLimit.rawValue)
        }
    }

    @Published var userAgentId: String {
        didSet {
            defaults.set(userAgentId, forKey: Keys.userAgentId.rawValue)
        }
    }

    @Published var lastWebURL: String {
        didSet {
            defaults.set(lastWebURL, forKey: Keys.lastWebURL.rawValue)
        }
    }

    private init() {
        self.downloadPath =
            defaults.string(forKey: Keys.downloadPath.rawValue)
            ?? FileUtils.defaultDownloadDirectory.path
        self.m3u8SegmentLimit = defaults.integer(forKey: Keys.m3u8SegmentLimit.rawValue)
        self.userAgentId =
            defaults.string(forKey: Keys.userAgentId.rawValue)
            ?? "default"
        self.lastWebURL =
            defaults.string(forKey: Keys.lastWebURL.rawValue)
            ?? "https://www.apple.com"
    }

    var downloadDirectoryURL: URL {
        URL(fileURLWithPath: downloadPath)
    }

    var currentUserAgent: String {
        UserAgentManager.shared.option(forId: userAgentId)?.userAgentString ?? ""
    }

    func resetToDefaults() {
        downloadPath = FileUtils.defaultDownloadDirectory.path
        m3u8SegmentLimit = 0
        userAgentId = "default"
    }
}
