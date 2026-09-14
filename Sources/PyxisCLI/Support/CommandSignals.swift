import Darwin
import Dispatch

/// Installed only by the CLI entry point; tests and library clients retain their signal handlers.
internal final class CommandSignals {
	private let sources: [any DispatchSourceSignal]
	private let handlers: [(Int32, sig_t?)]

	internal init(cancel: @escaping @Sendable () -> Void) {
		let numbers: [Int32] = [SIGINT, SIGTERM]
		self.handlers = numbers.map { ($0, signal($0, SIG_IGN)) }
		self.sources = numbers.map { number in
			let source = DispatchSource.makeSignalSource(signal: number, queue: .global())
			source.setEventHandler(handler: cancel)
			source.resume()
			return source
		}
	}

	internal func stop() {
		for source in sources { source.cancel() }
		for (number, handler) in handlers { signal(number, handler) }
	}
}
