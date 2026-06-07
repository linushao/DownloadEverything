import Foundation

enum UserAgentPlatform: String, CaseIterable, Identifiable {
    case iphone = "iPhone"
    case android = "Android"
    case desktop = "桌面端"
    case `default` = "系统默认"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .iphone: return "iPhone"
        case .android: return "Android"
        case .desktop: return "桌面端"
        case .default: return "系统默认"
        }
    }
}

struct UserAgentOption: Identifiable {
    let id: String
    let name: String
    let platform: UserAgentPlatform
    let userAgentString: String
}

final class UserAgentManager {
    static let shared = UserAgentManager()
    
    private init() {}
    
    let iphoneOptions: [UserAgentOption] = [
        UserAgentOption(
            id: "iphone-15-pro",
            name: "iPhone 15 Pro (Safari)",
            platform: .iphone,
            userAgentString: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        ),
        UserAgentOption(
            id: "iphone-14",
            name: "iPhone 14 (Safari)",
            platform: .iphone,
            userAgentString: "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        ),
        UserAgentOption(
            id: "iphone-13",
            name: "iPhone 13 (Safari)",
            platform: .iphone,
            userAgentString: "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        ),
        UserAgentOption(
            id: "iphone-12",
            name: "iPhone 12 (Safari)",
            platform: .iphone,
            userAgentString: "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1"
        )
    ]
    
    let androidOptions: [UserAgentOption] = [
        UserAgentOption(
            id: "samsung-s24",
            name: "Samsung Galaxy S24 (Chrome)",
            platform: .android,
            userAgentString: "Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36"
        ),
        UserAgentOption(
            id: "pixel-8",
            name: "Google Pixel 8 (Chrome)",
            platform: .android,
            userAgentString: "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36"
        ),
        UserAgentOption(
            id: "xiaomi-14",
            name: "Xiaomi 14 (Chrome)",
            platform: .android,
            userAgentString: "Mozilla/5.0 (Linux; Android 14; 23127PN5BC) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36"
        ),
        UserAgentOption(
            id: "huawei-mate60",
            name: "Huawei Mate 60 (Chrome)",
            platform: .android,
            userAgentString: "Mozilla/5.0 (Linux; Android 14; ALN-AL80) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.144 Mobile Safari/537.36"
        )
    ]
    
    let desktopOptions: [UserAgentOption] = [
        UserAgentOption(
            id: "macos-safari",
            name: "macOS Safari",
            platform: .desktop,
            userAgentString: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        ),
        UserAgentOption(
            id: "macos-chrome",
            name: "macOS Chrome",
            platform: .desktop,
            userAgentString: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.129 Safari/537.36"
        ),
        UserAgentOption(
            id: "windows-chrome",
            name: "Windows Chrome",
            platform: .desktop,
            userAgentString: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.109 Safari/537.36"
        ),
        UserAgentOption(
            id: "windows-edge",
            name: "Windows Edge",
            platform: .desktop,
            userAgentString: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.109 Safari/537.36 Edg/120.0.2210.91"
        ),
        UserAgentOption(
            id: "windows-firefox",
            name: "Windows Firefox",
            platform: .desktop,
            userAgentString: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
        )
    ]
    
    let defaultOption: UserAgentOption = UserAgentOption(
        id: "default",
        name: "系统默认",
        platform: .default,
        userAgentString: ""
    )
    
    var allOptions: [UserAgentOption] {
        [defaultOption] + iphoneOptions + androidOptions + desktopOptions
    }
    
    func option(forId id: String) -> UserAgentOption? {
        allOptions.first { $0.id == id }
    }
    
    func options(for platform: UserAgentPlatform) -> [UserAgentOption] {
        switch platform {
        case .iphone: return iphoneOptions
        case .android: return androidOptions
        case .desktop: return desktopOptions
        case .default: return [defaultOption]
        }
    }
}