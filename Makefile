output ?= .agents/interfaces
platform ?= macos
swift_sdk ?=

# The executable and its command plugin are macOS-only. iOS exposes the five libraries.
ifeq ($(platform),ios)
interface_targets = --target PyxisCore --target PyxisModel --target PyxisProcessing --target PyxisRuntime --target PyxisXCTest
endif

.PHONY: swiftinterface test
swiftinterface:
	@./scripts/generate-swiftinterfaces.sh --package-path . --output "$(output)" --platform "$(platform)" $(interface_targets) $(if $(swift_sdk),--swift-sdk "$(swift_sdk)")

test:
	swift test
