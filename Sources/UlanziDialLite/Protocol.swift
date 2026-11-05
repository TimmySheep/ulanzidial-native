import AppKit
import CoreBluetooth
import Foundation

// MARK: - 日志

let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/UlanziDialNative.log")
private let logQueue = DispatchQueue(label: "ulanzi.log")

func logLine(_ msg: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    let line = "[\(ts)] \(msg)\n"
    logQueue.async {
        if let h = try? FileHandle(forWritingTo: logURL) {
            h.seekToEndOfFile()
            h.write(Data(line.utf8))
            try? h.close()
        } else {
            try? Data(line.utf8).write(to: logURL)
        }
    }
}

// MARK: - TEA（原始 TEA，32 轮；20 字节包只加密前 16 字节，尾部 4 字节明文）

enum TEA {
    static let k0: UInt32 = 0xcaa5baca
    static let k1: UInt32 = 0xbc2a8a6d
    static let k2: UInt32 = 0xca5a9eba
    static let k3: UInt32 = 0x9bb88bca
    static let delta: UInt32 = 0x9e3779b9

    static func crypt(_ input: [UInt8], decrypt: Bool) -> [UInt8] {
        var out = input
        var off = 0
        while off + 8 <= out.count {
            var v0 = UInt32(out[off]) | UInt32(out[off + 1]) << 8 | UInt32(out[off + 2]) << 16 | UInt32(out[off + 3]) << 24
            var v1 = UInt32(out[off + 4]) | UInt32(out[off + 5]) << 8 | UInt32(out[off + 6]) << 16 | UInt32(out[off + 7]) << 24
            if decrypt {
                var s = delta &* 32
                for _ in 0..<32 {
                    v1 = v1 &- (((v0 &<< 4) &+ k2) ^ (v0 &+ s) ^ ((v0 >> 5) &+ k3))
                    v0 = v0 &- (((v1 &<< 4) &+ k0) ^ (v1 &+ s) ^ ((v1 >> 5) &+ k1))
                    s = s &- delta
                }
            } else {
                var s: UInt32 = 0
                for _ in 0..<32 {
                    s = s &+ delta
                    v0 = v0 &+ (((v1 &<< 4) &+ k0) ^ (v1 &+ s) ^ ((v1 >> 5) &+ k1))
                    v1 = v1 &+ (((v0 &<< 4) &+ k2) ^ (v0 &+ s) ^ ((v0 >> 5) &+ k3))
                }
            }
            out[off] = UInt8(v0 & 0xff)
            out[off + 1] = UInt8((v0 >> 8) & 0xff)
            out[off + 2] = UInt8((v0 >> 16) & 0xff)
            out[off + 3] = UInt8((v0 >> 24) & 0xff)
            out[off + 4] = UInt8(v1 & 0xff)
            out[off + 5] = UInt8((v1 >> 8) & 0xff)
            out[off + 6] = UInt8((v1 >> 16) & 0xff)
            out[off + 7] = UInt8((v1 >> 24) & 0xff)
            off += 8
        }
        return out
    }

    static func encrypt(_ input: [UInt8]) -> [UInt8] { crypt(input, decrypt: false) }
    static func decrypt(_ input: [UInt8]) -> [UInt8] { crypt(input, decrypt: true) }

    /// 公开抓包向量自检（4 组，双向）
    static func selfTest() -> Bool {
        let vectors: [(String, String, String)] = [
            ("top-left down", "8b10010100000000000000000000000000000000", "8e8f5e16ec67281e3890c499a360aaad00000000"),
            ("top-left up", "8b10010000000000000000000000000000000000", "028db3660224d0c73890c499a360aaad00000000"),
            ("host periodic", "0601230001000000000000000000000000000000", "24569ef228e145a13890c499a360aaad00000000"),
            ("dev reply", "0601231001000000000000000000000000000000", "21f45eb71c3587ab3890c499a360aaad00000000"),
        ]
        var ok = true
        for (name, plainHex, cipherHex) in vectors {
            let plain = [UInt8](hex: plainHex)
            let cipher = [UInt8](hex: cipherHex)
            let pass = encrypt(plain) == cipher && decrypt(cipher) == plain
            ok = ok && pass
            logLine("selftest \(name): \(pass ? "OK" : "FAIL")")
        }
        logLine("selftest overall: \(ok ? "PASS" : "FAIL")")
        return ok
    }
}

extension Array where Element == UInt8 {
    init(hex: String) {
        var bytes = [UInt8]()
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if let b = UInt8(hex[idx..<next], radix: 16) { bytes.append(b) }
            idx = next
        }
        self = bytes
    }

    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}

// MARK: - 设备连接

final class DialLink: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let svcUUID = CBUUID(string: "00001971-0000-1000-8000-00805F9B34FB")
    static let writeUUID = CBUUID(string: "0000FD01-0000-1000-8000-00805F9B34FB")
    static let notifyUUID = CBUUID(string: "0000FD00-0000-1000-8000-00805F9B34FB")
    /// 标准 GATT 电量特征（Battery Service 0x180F）
    static let batteryUUID = CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")

    var onEvent: ((Control, Bool) -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCh: CBCharacteristic?
    private var notifyCh: CBCharacteristic?
    private var batteryCh: CBCharacteristic?
    private var hbTimer: Timer?
    private var scanTimer: Timer?
    private var wantsReconnect = true

    @Published private(set) var stateText = "启动中"
    @Published private(set) var isOnline = false
    @Published private(set) var batteryText = "—"
    func start() {
        if UserDefaults.standard.object(forKey: "lastBattery") != nil {
            batteryText = "\(UserDefaults.standard.integer(forKey: "lastBattery"))%"
        }
        central = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        logLine("central.state = \(stateName(c.state))")
        switch c.state {
        case .poweredOn:
            stateText = "扫描中"
            let known = c.retrieveConnectedPeripherals(withServices: [Self.svcUUID])
            logLine("retrieveConnectedPeripherals -> \(known.count)")
            if let p = known.first {
                attach(p)
            } else {
                startScan()
            }
        case .unauthorized:
            stateText = "蓝牙未授权"
        case .poweredOff:
            stateText = "蓝牙已关闭"
        default:
            stateText = "蓝牙不可用（\(stateName(c.state))）"
        }
    }

    /// 设置界面里的「重新连接」
    func reconnect() {
        logLine("manual reconnect requested")
        wantsReconnect = true
        stopHeartbeat()
        isOnline = false
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        } else {
            startScan()
        }
    }

    private func stateName(_ s: CBManagerState) -> String {
        switch s {
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff: return "poweredOff"
        case .poweredOn: return "poweredOn"
        @unknown default: return "unexpected"
        }
    }

    private func startScan() {
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.central.stopScan()
            if self.peripheral == nil {
                self.stateText = "未找到设备"
                logLine("扫描 15 秒未找到 Ulanzi 设备，稍后重试")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    guard let self, self.peripheral == nil else { return }
                    self.startScan()
                }
            }
        }
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = p.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        guard name.lowercased().contains("ulanzi") else { return }
        logLine("discovered \(name) rssi=\(RSSI)")
        c.stopScan()
        scanTimer?.invalidate()
        attach(p)
    }

    private func attach(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        stateText = "连接中"
        logLine("connecting \(p.name ?? p.identifier.uuidString)")
        central.connect(p, options: nil)
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        logLine("connected \(p.name ?? "-")")
        stateText = "发现服务"
        p.discoverServices(nil)
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        logLine("didFailToConnect: \(error?.localizedDescription ?? "-")")
        stateText = "连接失败"
        peripheral = nil
        startScan()
    }

    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        logLine("disconnected: \(error?.localizedDescription ?? "no error")")
        stopHeartbeat()
        isOnline = false
        writeCh = nil
        notifyCh = nil
        stateText = "已断开"
        guard wantsReconnect else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, let p = self.peripheral else { return }
            self.stateText = "重连中"
            self.central.connect(p, options: nil)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { logLine("didDiscoverServices error: \(error.localizedDescription)"); return }
        for s in p.services ?? [] {
            p.discoverCharacteristics(nil, for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        if let error { logLine("didDiscoverCharacteristics error: \(error.localizedDescription)"); return }
        for ch in s.characteristics ?? [] {
            if ch.uuid == Self.writeUUID { writeCh = ch }
            if ch.uuid == Self.notifyUUID { notifyCh = ch }
            if ch.uuid == Self.batteryUUID { batteryCh = ch }
        }

        // 标准电量特征：订阅并主动读一次
        if let b = batteryCh {
            p.setNotifyValue(true, for: b)
            p.readValue(for: b)
            logLine("battery characteristic found, reading…")
        }

        if let n = notifyCh, writeCh != nil {
            p.setNotifyValue(true, for: n)
        } else if notifyCh == nil && writeCh == nil {
            logLine("未找到 fd00/fd01 特征值，停止")
            stateText = "特征值不匹配"
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor ch: CBCharacteristic, error: Error?) {
        if let error { logLine("notify state error: \(error.localizedDescription)"); return }
        logLine("notify \(ch.uuid) isNotifying=\(ch.isNotifying)")
        if ch.isNotifying {
            isOnline = true
            stateText = "在线模式"
            sendHeartbeat()
            hbTimer?.invalidate()
            hbTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.sendHeartbeat()
            }
        }
    }

    private func stopHeartbeat() {
        hbTimer?.invalidate()
        hbTimer = nil
    }

    private func sendHeartbeat() {
        guard let p = peripheral, let ch = writeCh else { return }
        var plain = [UInt8](repeating: 0, count: 20)
        plain[0] = 0x06; plain[1] = 0x01; plain[2] = 0x23; plain[3] = 0x00; plain[4] = 0x01
        p.writeValue(Data(TEA.encrypt(plain)), for: ch, type: .withoutResponse)
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard let data = ch.value else { return }

        // 标准 GATT 电量
        if ch.uuid == Self.batteryUUID {
            let bytes = [UInt8](data)
            if let pct = bytes.first, pct <= 100 {
                batteryText = "\(pct)%"
                UserDefaults.standard.set(Int(pct), forKey: "lastBattery")
                logLine("battery(GATT) \(pct)%")
            }
            return
        }

        let plain = TEA.decrypt([UInt8](data))
        decode(plain)
    }

    private func decode(_ m: [UInt8]) {
        guard m.count >= 4 else { return }
        if m[0] == 0x8b && m[1] == 0x10 {
            let id = m[2]
            let isDown = m[3] == 0x01
            logLine("event id=0x\(String(format: "%02x", id)) \(isDown ? "down/step" : "up")")
            if let control = Control.from(id: id) {
                onEvent?(control, isDown)
            }
        } else if m[0] == 0x0b && m[1] == 0x7b {
            let pct = m.count > 5 ? Int(m[5]) : 0
            batteryText = "\(pct)%"
            UserDefaults.standard.set(pct, forKey: "lastBattery")
            logLine("battery \(pct)%")
        }
    }
}
