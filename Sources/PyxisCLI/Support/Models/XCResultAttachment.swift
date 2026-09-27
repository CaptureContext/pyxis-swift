internal struct XCResultAttachment: Decodable {
	internal var exportedFileName: String
	internal var suggestedHumanReadableName: String
	internal var configurationName: String
	internal var deviceID: String
	internal var repetitionNumber: Int?
	internal var arguments: [String]?

	internal init(
		exportedFileName: String,
		suggestedHumanReadableName: String,
		configurationName: String,
		deviceID: String,
		repetitionNumber: Int?,
		arguments: [String]? = nil
	) {
		self.exportedFileName = exportedFileName
		self.suggestedHumanReadableName = suggestedHumanReadableName
		self.configurationName = configurationName
		self.deviceID = deviceID
		self.repetitionNumber = repetitionNumber
		self.arguments = arguments
	}

	private enum CodingKeys: String, CodingKey {
		case exportedFileName
		case suggestedHumanReadableName
		case configurationName
		case deviceID = "deviceId"
		case repetitionNumber
		case arguments
	}
}
