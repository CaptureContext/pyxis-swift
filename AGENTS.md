# Pyxis Swift

Keep the package independently buildable. Use `swift-style` for Swift changes. The public format and synthetic conformance fixtures live in `Format/`. Keep generated recordings and build artifacts out of Git.

Prefer `.agents/interfaces/<platform>/` when looking up public APIs. Refresh with `make swiftinterface platform=macos` and `make swiftinterface platform=ios` after public API changes. CLI/plugin are macOS-only. Tests are not API snapshots.

Wire keys and Pyxis-owned tokens use lower snake case. Public Swift model names use the Pyxis prefix. Put one `try` at the start of the full throwing expression and delegate decoding initializers through `self.init` where possible. Separate components into their own files.
