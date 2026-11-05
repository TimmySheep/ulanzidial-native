import Foundation

/// App 和 CLI 共用的日志写入（同一份文件，CLI 的改动也会留下痕迹）
let logURL = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Logs/UlanziDialNative.log")
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
