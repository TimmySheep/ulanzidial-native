import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = BindingStore()
    let link = DialLink()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logLine("=== UlanziDialLite 启动 ===")
        _ = TEA.selfTest()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "○ Dial"

        let menu = NSMenu()
        let status = NSMenuItem(title: "状态：启动中", action: nil, keyEquivalent: "")
        status.tag = 1
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "设置按键…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let login = NSMenuItem(title: "开机自动启动", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let log = NSMenuItem(title: "打开日志", action: #selector(openLog), keyEquivalent: "l")
        log.target = self
        menu.addItem(log)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu

        link.onEvent = { [weak self] control, isDown in
            self?.handle(control: control, isDown: isDown)
        }
        link.start()

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.statusItem.menu?.item(withTag: 1)?.title = "状态：\(self.link.stateText)"
            self.statusItem.button?.title = self.link.isOnline ? "◉ Dial" : "○ Dial"
        }
    }

    /// 只在按下/步进时触发一次；旋钮点击是松手时补发的 down+up 对，因此只认 down
    private func handle(control: Control, isDown: Bool) {
        guard isDown else { return }
        let action = store.binding(control)
        guard action.kind != .none else { return }
        logLine("ACTION \(control.name) -> \(action.describe)")
        Actions.perform(action)
    }

    @objc func showSettings() {
        if let w = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView(store: store, link: link)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 660),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Ulanzi Dial Lite — 按键设置"
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc func toggleLogin() {
        let enable = !LoginItem.isEnabled
        if let error = LoginItem.setEnabled(enable) {
            logLine("开机自启设置失败: \(error)")
            let alert = NSAlert()
            alert.messageText = "无法\(enable ? "开启" : "关闭")开机自启"
            alert.informativeText = error
            alert.alertStyle = .warning
            alert.runModal()
        }
        statusItem.menu?.item(withTitle: "开机自动启动")?.state = LoginItem.isEnabled ? .on : .off
    }

    @objc func openLog() {
        NSWorkspace.shared.open(logURL)
    }

    @objc func quit() {
        logLine("=== 退出 ===")
        NSApp.terminate(nil)
    }
}
