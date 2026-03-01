/// Configuration options for the XML writer.
public struct EmitterConfig: Sendable {
    /// When `true`, an XML declaration (`<?xml ...?>`) is emitted at the start.
    public var writeDocumentDeclaration: Bool

    /// When `true`, the output is pretty-printed with indentation.
    public var performIndent: Bool

    /// The string used for each level of indentation (default: two spaces).
    public var indentString: String

    /// The line separator string (default: newline).
    public var lineSeparator: String

    /// Creates an emitter configuration with the given options.
    public init(
        writeDocumentDeclaration: Bool = true,
        performIndent: Bool = false,
        indentString: String = "  ",
        lineSeparator: String = "\n"
    ) {
        self.writeDocumentDeclaration = writeDocumentDeclaration
        self.performIndent = performIndent
        self.indentString = indentString
        self.lineSeparator = lineSeparator
    }
}
