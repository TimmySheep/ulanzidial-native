import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = BindingStore()
    let settings = AppSettings()
    let link = DialLink()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logLine("=== UlanziDialLite 启动（无菜单栏 / 无 Dock 图标）===")
        _ = TEA.selfTest()

        link.onEvent = { [weak self] control, isDown in
            self?.handle(control: control, isDown: isDown)
        }
        link.start()

        HotKeyCenter.shared.onPress = { [weak self] in self?.showSettings() }
        HotKeyCenter.shared.apply(settings: settings)

        UpdateChecker.checkOnLaunch()

        // 前台 App 变化 → 按规则切换配置
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            // 正在设置界面里操作时不自动切换，避免眼前这套配置突然变掉
            if self.settingsWindow?.isKeyWindow == true { return }
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard let bundle = app.bundleIdentifier, bundle != Bundle.main.bundleIdentifier else { return }
            self.store.applyAppRule(bundleID: bundle)
        }

        // 首次运行弹一次设置窗口，之后（含开机自启）完全静默
        if !UserDefaults.standard.bool(forKey: "didLaunchBefore") {
            UserDefaults.standard.set(true, forKey: "didLaunchBefore")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showSettings()
            }
        }
    }

    /// 已经在运行时再次双击 App / `open` 会走到这里 → 打开设置
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    /// 关掉设置窗口不退出，继续在后台工作
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - 单击 / 双击 / 长按

    private lazy var gestures: GestureTracker = {
        GestureTracker(
            hasBinding: { [weak self] control, gesture in
                guard let self else { return false }
                return self.store.action(control, gesture: gesture).kind != .none
            },
            fire: { [weak self] control, gesture in
                guard let self else { return }
                let action = self.store.action(control, gesture: gesture)
                guard action.kind != .none else { return }
                logLine("ACTION \(control.name)[\(gesture.name)] -> \(action.describe)")
                Actions.perform(action)
            }
        )
    }()

    /// 设备事件入口：转动类直通，按键走手势判定
    private func handle(control: Control, isDown: Bool) {
        if isDown {
            gestures.down(control)
        } else {
            gestures.up(control)
        }
    }

    @objc func showSettings() {
        if let w = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "UlanziDial Native"
        window.minSize = NSSize(width: 820, height: 560)
        window.contentView = NSHostingView(rootView: SettingsView(store: store, settings: settings, link: link))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc func openLog() {
        NSWorkspace.shared.open(logURL)
    }

    @objc func quit() {
        logLine("=== 退出 ===")
        NSApp.terminate(nil)
    }
}
