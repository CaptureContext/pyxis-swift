internal struct XCResultTestAttachments: Decodable {
	internal var testIdentifier: String
	internal var attachments: [XCResultAttachment]

	internal init(
		testIdentifier: String,
		attachments: [XCResultAttachment]
	) {
		self.testIdentifier = testIdentifier
		self.attachments = attachments
	}
}
