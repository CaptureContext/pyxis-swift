import Foundation
import SwiftUI
import UIKit
import Testing
import SnapshotTesting
import ExampleSnapshotTesting
@testable import ExampleApp

@MainActor
@Suite(.serialized)
internal struct ExampleSnapshots {
	@Test(arguments: [false, true])
	internal func notebooks(empty: Bool) async throws {
		try await record(key: empty ? "states.notebooks.empty" : "states.notebooks.populated", title: "Notebook fixtures") { recorder, profile in
			try await recorder.capture(
				empty ? .notebooksEmpty : .notebooks,
				value: controller(NotebooksView(notes: .constant(empty ? [] : [.weekend, .ideas])), profile: profile),
				as: strategy(profile: profile)
			)
		}
	}

	@Test
	internal func noteDetails() async throws {
		try await record(key: "states.detail", title: "Note content") { recorder, profile in
			try await recorder.capture(.detail, value: controller(NoteDetailView(note: .weekend), profile: profile), as: strategy(profile: profile))
			let longNote: Note = .init(
				id: "long", title: "A notebook full of possibilities", notebook: "Ideas",
				body: String(repeating: "Make room for a small experiment. Write down what you learned and try again tomorrow.\n\n", count: 8),
				symbol: "lightbulb"
			)
			try await recorder.capture(
				.init(id: "detail_long", screenID: "detail", domainID: "notes", title: "Note", label: "Long content", order: 2),
				value: controller(NoteDetailView(note: longNote), profile: profile), as: strategy(profile: profile)
			)
		}
	}

	private func record(
		key: String,
		title: String,
		body: (PyxisSnapshotRecorder, ExampleProfile) async throws -> Void
	) async throws {
		let environment: PyxisRecordingEnvironment = try .init(environment: ProcessInfo.processInfo.environment)
		if let model = environment.deviceModel, model != ExampleDevice.simulatorModel {
			throw PyxisValidationError("Snapshot runner does not match the requested simulator model")
		}
		let profile: ExampleProfile = try .init(recordingEnvironment: ProcessInfo.processInfo.environment)
		let recording: PyxisProfile = profile.recording(environment: environment)
		let report: PyxisBootstrapReport = .init(variants: recording.requested.mapValues { .init(status: .applied, value: $0) })
		try await withPyxisRecording(
			configuration: .init(
				project: .init(id: "pyxis.ios-example", title: "Notes · Pyxis example"),
				run: .init(
					id: environment.runID ?? "example-local-v3",
					createdAt: environment.runCreatedAt ?? Date(timeIntervalSince1970: 1789344000),
					provenance: ["fixture": "swiftui-notes-v3"]
				),
				domains: [.notes, .settings], profile: recording
			),
			recordingKey: key, journeyID: "notebook-fixtures", title: title, report: report
		) { try await body($0, profile) }
	}

	private func strategy(profile: ExampleProfile) -> Snapshotting<UIViewController, UIImage> {
		let window: UIWindow? = UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }.first?.keyWindow
		let traits: UITraitCollection = (window?.traitCollection ?? .init()).modifyingTraits {
			$0.userInterfaceStyle = profile.colorScheme == .dark ? .dark : .light
			$0.layoutDirection = profile.direction == .rtl ? .rightToLeft : .leftToRight
			$0.preferredContentSizeCategory = profile.contentSize == .xxxLarge ? .extraExtraExtraLarge : .large
		}
		let bounds: CGSize = window?.bounds.size ?? UIScreen.main.bounds.size
		let shortEdge: CGFloat = min(bounds.width, bounds.height)
		let longEdge: CGFloat = max(bounds.width, bounds.height)
		let size: CGSize = profile.orientation == .portrait
		? .init(width: shortEdge, height: longEdge)
		: .init(width: longEdge, height: shortEdge)
		let viewStrategy: Snapshotting<UIView, UIImage> = .image(size: size, traits: traits)
		var strategy: Snapshotting<UIViewController, UIImage> = viewStrategy.pullback { controller in
			// Keep the fixture viewport independent of the host window's current rotation.
			controller.view.autoresizingMask = []
			controller.view.frame = .init(origin: .zero, size: size)
			return controller.view
		}
		let snapshot = strategy.snapshot
		strategy.snapshot = { controller in
			snapshot(controller).map { image in
				#expect((image.size.width > image.size.height) == (profile.orientation == .landscape))
				return image
			}
		}
		return strategy
	}

	private func controller<Content: View>(_ content: Content, profile: ExampleProfile) -> UIViewController {
		let view = NavigationStack { content }
			.tint(.indigo)
			.environment(\.colorScheme, profile.colorScheme == .dark ? .dark : .light)
			.environment(\.layoutDirection, profile.direction == .rtl ? .rightToLeft : .leftToRight)
			.environment(\.dynamicTypeSize, profile.contentSize == .xxxLarge ? .xxxLarge : .large)
		let controller: UIHostingController = .init(rootView: view)
		controller.overrideUserInterfaceStyle = profile.colorScheme == .dark ? .dark : .light
		controller.view.frame = CGRect(origin: .zero, size: UIScreen.main.bounds.size)
		return controller
	}
}
