import Foundation
import PyxisCore
import PyxisModel

/// Builds one execution's fragment. The adapter owns rendering and attachment transport.
@MainActor
public final class PyxisRecordingSession {
	public private(set) var document: PyxisMapDocument
	public private(set) var isFinished: Bool = false
	private var sequence: Int = 0
	private var revision: Int = 0
	private let attach: @MainActor (Data, String) throws -> Void

	public init(
		configuration: PyxisSessionConfiguration,
		recordingKey: String?,
		journeyID: String,
		title: String,
		testName: String,
		producer: PyxisRecordingProducer,
		executionID: String = UUID().uuidString,
		report: PyxisBootstrapReport = .init(variants: [:]),
		attach: @escaping @MainActor (Data, String) throws -> Void
	) {
		self.attach = attach
		self.document = .init(
			format: .fragment,
			project: configuration.project,
			run: configuration.run,
			domains: configuration.domains,
			profiles: [configuration.profile],
			observations: [.init(
				id: "o_" + StableID.digest(parts: [
					"execution", configuration.project.id, configuration.run.id,
					recordingKey ?? journeyID, testName, configuration.profile.id, executionID,
				]),
				journeyID: journeyID,
				title: title,
				testName: testName,
				profileID: configuration.profile.id,
				variants: report.covering(configuration.profile.requested).variants,
				recordingKey: recordingKey,
				producer: producer
			)]
		)
	}

	public func updateReport(_ report: PyxisBootstrapReport) throws {
		try requireActive()
		document.observations[0].variants = report.covering(document.profiles[0].requested).variants
	}

	public func declare(_ state: PyxisState) throws {
		try requireActive()
		if let existing = document.states.first(where: { Data($0.id.utf8) == Data(state.id.utf8) }) {
			let encoder: JSONEncoder = .init()
			encoder.outputFormatting = [.sortedKeys]
			guard try encoder.encode(existing) == encoder.encode(state)
			else { throw PyxisRecordingError.conflictingState(state.id) }
		} else {
			document.states.append(state)
		}
	}

	public func capture(_ state: PyxisState, png: Data, width: Int, height: Int) throws {
		try declare(state)
		guard width > 0, height > 0, !png.isEmpty
		else { throw PyxisRecordingError.invalidImage }
		let observationID: String = document.observations[0].id
		let occurrence: Int = document.captures.filter { Data($0.stateID.utf8) == Data(state.id.utf8) }.count
		let id: String = StableID.capture(observationID: observationID, stateID: state.id, occurrence: occurrence)
		try attach(png, "\(id).png")
		document.captures.append(.init(
			id: id, stateID: state.id, observationID: observationID, sequence: nextSequence(),
			asset: .init(path: "assets/\(id).png", mediaType: .png, width: width, height: height)
		))
		try checkpoint()
	}

	public func beginTransition(from source: PyxisState, to destination: PyxisState, action: String, kind: String, key: String? = nil) throws -> Int {
		try requireActive()
		guard document.captures.contains(where: { Data($0.stateID.utf8) == Data(source.id.utf8) })
		else { throw PyxisRecordingError.sourceNotCaptured(source.id) }
		try declare(source)
		try declare(destination)
		let sequence: Int = nextSequence()
		let index: Int = document.transitions.count
		document.transitions.append(.init(
			id: StableID.transition(observationID: document.observations[0].id, sequence: sequence),
			observationID: document.observations[0].id,
			fromStateID: source.id, toStateID: destination.id, action: action, kind: kind,
			sequence: sequence, status: .failed, failure: "Transition did not complete.", key: key
		))
		try checkpoint()
		return index
	}

	public func succeedTransition(_ index: Int) throws {
		try requireActive()
		guard document.transitions.indices.contains(index)
		else { throw PyxisRecordingError.unknownTransition }
		document.transitions[index].status = .succeeded
		document.transitions[index].failure = nil
		try checkpoint()
	}

	public func fail(_ error: any Error, transition index: Int? = nil) throws {
		try requireActive()
		if let index {
			guard document.transitions.indices.contains(index)
			else { throw PyxisRecordingError.unknownTransition }
			document.transitions[index].status = .failed
			document.transitions[index].failure = String(describing: error)
		}
		document.observations[0].status = .failed
		document.observations[0].failure = String(describing: error)
		try checkpoint()
	}

	public func finish(status: PyxisObservationStatus, failure: String? = nil) throws {
		guard !isFinished else { return }
		let failed: Bool = document.observations[0].status == .failed || document.transitions.contains { $0.status == .failed }
		document.observations[0].status = failed ? .failed : status
		document.observations[0].failure = failure ?? document.observations[0].failure
		try checkpoint()
		isFinished = true
	}

	public func checkpoint() throws {
		try PyxisValidation.validate(document)
		try attach(PyxisJSON.encode(document), "pyxis-fragment-\(document.observations[0].id)-\(revision).json")
		revision += 1
	}

	private func requireActive() throws {
		guard !isFinished else { throw PyxisRecordingError.alreadyFinished }
	}

	private func nextSequence() -> Int {
		defer { sequence += 1 }
		return sequence
	}
}
