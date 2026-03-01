/// Configuration options for the XML parser.
public struct ParserConfig: Sendable {
    /// When `true`, comment nodes are omitted from the parsed tree.
    public var ignoreComments: Bool

    /// When `true`, processing instruction nodes are omitted from the parsed tree.
    public var ignoreProcessingInstructions: Bool

    /// Creates a parser configuration with the given options.
    public init(
        ignoreComments: Bool = false,
        ignoreProcessingInstructions: Bool = false
    ) {
        self.ignoreComments = ignoreComments
        self.ignoreProcessingInstructions = ignoreProcessingInstructions
    }
}
