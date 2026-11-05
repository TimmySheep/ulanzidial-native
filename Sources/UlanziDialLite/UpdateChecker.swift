import AppKit
import Foundation

/// 检查更新：查 Timmy 自己的站点上的 version.json（不走 GitHub API）
enum UpdateChecker {
    /// 版本清单地址（个人网站维护）
    static let feedURL = URL(string: "https://timhuang.net/ulanzidial-native/version.json")!

    struct Feed: Decodable {
        var version: String
        var url: String?
        var notes: [String]?
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// 启动后延迟检查，避免和蓝牙连接抢时间
    static func checkOnLaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            check(userInitiated: false)
        }
    }

    static func check(userInitiated: Bool) {
        var request = URLRequest(url: feedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        request.setValue("DialNative/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        logLine("update check → \(feedURL.absoluteString)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                logLine("update check failed: \(error.localizedDescription)")
                if userInitiated {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "检查更新失败"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
                return
            }

            guard let data, let feed = try? JSONDecoder().decode(Feed.self, from: data) else {
                logLine("update feed 解析失败")
                return
            }

            let current = currentVersion
            logLine("update feed: remote=\(feed.version) local=\(current)")

            guard isNewer(feed.version, than: current) else {
                if userInitiated {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "已是最新版本"
                        alert.informativeText = "当前版本 \(current)"
                        alert.runModal()
                    }
                }
                return
            }

            let skipped = UserDefaults.standard.string(forKey: "skippedVersion")
            if !userInitiated, skipped == feed.version {
                logLine("update \(feed.version) skipped by user")
                return
            }

            DispatchQueue.main.async { present(feed, current: current) }
        }.resume()
    }

    private static func present(_ feed: Feed, current: String) {
        let alert = NSAlert()
        alert.messageText = "有新版本 \(feed.version)"
        var lines = ["当前版本 \(current)。"]
        if let notes = feed.notes, !notes.isEmpty {
            lines.append("")
            lines.append(contentsOf: notes.map { "· \($0)" })
        }
        alert.informativeText = lines.joined(separator: "\n")
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "稍后提醒")
        alert.addButton(withTitle: "跳过此版本")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if let raw = feed.url, let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
            }
            logLine("update: opened \(feed.url ?? "-")")
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(feed.version, forKey: "skippedVersion")
            logLine("update: skipped \(feed.version)")
        default:
            logLine("update: postponed \(feed.version)")
        }
    }

    /// 简单语义化比较：1.2.3 > 1.2.0
    static func isNewer(_ a: String, than b: String) -> Bool {
        let left = a.split(separator: ".").map { Int($0) ?? 0 }
        let right = b.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)
        for i in 0..<count {
            let l = i < left.count ? left[i] : 0
            let r = i < right.count ? right[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
