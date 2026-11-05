import Foundation
import ServiceManagement

// 开机自启：使用 Apple 官方 SMAppService（macOS 13+）
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "已开启"
        case .notRegistered: return "未开启"
        case .notFound: return "未找到应用（请把 App 放到固定位置）"
        case .requiresApproval: return "等待用户在系统设置中批准"
        @unknown default: return "未知状态"
        }
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            logLine("login item -> \(enabled ? "on" : "off"), status=\(statusText)")
            return nil
        } catch {
            logLine("login item 设置失败: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
