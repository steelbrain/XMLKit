/// Errors that can occur when parsing XML.
public enum XMLParseError: Error, Equatable, Sendable {
    /// The XML is structurally invalid, with source location.
    case malformedXML(String, line: Int, column: Int)
    /// The library was unable to parse this XML document.
    case cannotParse
}

extension XMLParseError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .malformedXML(let message, let line, let column):
            return "Malformed XML at \(line):\(column): \(message)"
        case .cannotParse:
            return "Cannot parse XML document"
        }
    }
}
