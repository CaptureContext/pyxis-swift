/// Both sibling scopes reach this suspension point before either can continue.
internal actor ConfigurationScopeBarrier {
	private var waiter: CheckedContinuation<Void, Never>?

	internal init() {
		self.waiter = nil
	}

	internal func arrive() async {
		if let waiter = self.waiter {
			self.waiter = nil
			waiter.resume()
			return
		}

		await withCheckedContinuation { self.waiter = $0 }
	}
}
