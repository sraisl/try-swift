import Dispatch
import Darwin

/// Watches SIGWINCH via DispatchSourceSignal, sidestepping the
/// async-signal-safety restrictions of a naive C signal handler: GCD
/// delivers the event handler as a normal closure on a worker thread, not
/// signal-delivery context, so it can safely touch Swift state.
public final class WinchWatcher {
    private var source: DispatchSourceSignal?
    private let queue = DispatchQueue(label: "try.winch-watcher", qos: .utility)

    public init(onResize: @escaping @Sendable () -> Void) {
        signal(SIGWINCH, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: queue)
        src.setEventHandler(handler: onResize)
        src.resume()
        self.source = src
    }

    public func cancel() {
        source?.cancel()
        source = nil
    }

    deinit {
        cancel()
    }
}
