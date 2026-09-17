import Foundation

enum Terminal {
    /// The terminal width in columns. Assumes 120 when it cannot be read, e.g. through a pipe.
    static var width: Int {
        var window = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &window) == 0, window.ws_col > 0 {
            return Int(window.ws_col)
        }
        if let columns = ProcessInfo.processInfo.environment["COLUMNS"], let value = Int(columns), value > 0 {
            return value
        }
        return 120
    }
}

extension String {
    /// Replaces the tail with an ellipsis when the string exceeds the given width.
    func truncated(to limit: Int) -> String {
        guard limit > 1, count > limit else { return self }
        return prefix(limit - 1) + "…"
    }
}
