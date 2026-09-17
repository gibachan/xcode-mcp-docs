import Foundation

/// Reads mcpbridge's standard output (newline-delimited JSON-RPC) and makes each response
/// retrievable by its `id`.
///
/// Waiting with a fixed `sleep` drops responses on some Xcode versions, so a waiter is
/// released the moment the response with the requested `id` arrives.
final class ResponseCollector: @unchecked Sendable {

    private let lock = NSLock()
    private var buffer = Data()
    private var responses: [Int: Data] = [:]
    private var semaphores: [Int: DispatchSemaphore] = [:]
    private var isFinished = false

    /// Feeds in whatever was read from standard output. Only complete lines are parsed.
    func ingest(_ data: Data) {
        guard !data.isEmpty else { return }
        var completedLines: [Data] = []

        DebugLog.log("stdout: received \(data.count) bytes")
        lock.lock()
        buffer.append(data)
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newlineIndex]
            buffer = buffer[buffer.index(after: newlineIndex)...]
            if !line.isEmpty {
                completedLines.append(Data(line))
            }
        }
        lock.unlock()

        DebugLog.log("complete lines: \(completedLines.count), pending buffer: \(buffer.count) bytes")
        for line in completedLines {
            store(line)
        }
    }

    /// Called when the process exits, to release every waiting caller.
    func finish() {
        lock.lock()
        isFinished = true
        let waiting = semaphores.values
        lock.unlock()
        waiting.forEach { $0.signal() }
    }

    /// Waits for the response with the given `id`. Returns `nil` if it does not arrive in time.
    func wait(id: Int, timeout: TimeInterval) -> Data? {
        lock.lock()
        if let response = responses[id] {
            lock.unlock()
            return response
        }
        if isFinished {
            lock.unlock()
            return nil
        }
        let semaphore = semaphores[id] ?? DispatchSemaphore(value: 0)
        semaphores[id] = semaphore
        lock.unlock()

        _ = semaphore.wait(timeout: .now() + timeout)

        lock.lock()
        defer { lock.unlock() }
        return responses[id]
    }

    private func store(_ line: Data) {
        guard
            let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
            let id = object["id"] as? Int
        else {
            DebugLog.log("ignoring a line without an id: \(line.count) bytes")
            // Notifications (which carry no id) and log lines are ignored.
            return
        }

        DebugLog.log("received the response for id=\(id) (\(line.count) bytes)")
        lock.lock()
        responses[id] = line
        let semaphore = semaphores[id]
        lock.unlock()
        semaphore?.signal()
    }
}
