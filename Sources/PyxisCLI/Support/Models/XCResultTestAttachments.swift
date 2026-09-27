internal struct XCResultTestAttachments: Decodable {
	internal var testIdentifier: String
	internal var testIdentifierURL: String?
	internal var attachments: [XCResultAttachment]

	internal init(
		testIdentifier: String,
		attachments: [XCResultAttachment],
		testIdentifierURL: String? = nil
	) {
		self.testIdentifier = testIdentifier
		self.testIdentifierURL = testIdentifierURL
		self.attachments = attachments
	}
}
