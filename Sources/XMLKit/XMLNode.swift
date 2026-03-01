/// Represents a node in an XML document tree.
public enum XMLNode: Hashable, Sendable {
    /// An XML element with a tag name, attributes, and children.
    case element(XMLElement)
    /// An XML comment (`<!-- ... -->`).
    case comment(String)
    /// A CDATA section (`<![CDATA[ ... ]]>`).
    case cdata(String)
    /// A text node.
    case text(String)
    /// A processing instruction (`<?target data?>`).
    case processingInstruction(String, String?)

    /// Returns the element if this node is an `.element`, otherwise `nil`.
    public var asElement: XMLElement? {
        if case .element(let elem) = self { return elem }
        return nil
    }

    /// Returns a mutable element reference via a closure, if this node is an `.element`.
    @discardableResult
    public mutating func withElement<T>(_ body: (inout XMLElement) -> T) -> T? {
        if case .element(var elem) = self {
            let result = body(&elem)
            self = .element(elem)
            return result
        }
        return nil
    }

    /// Returns the comment string if this node is a `.comment`, otherwise `nil`.
    public var asComment: String? {
        if case .comment(let content) = self { return content }
        return nil
    }

    /// Returns the CDATA string if this node is a `.cdata`, otherwise `nil`.
    public var asCData: String? {
        if case .cdata(let content) = self { return content }
        return nil
    }

    /// Returns the text string if this node is a `.text`, otherwise `nil`.
    public var asText: String? {
        if case .text(let content) = self { return content }
        return nil
    }

    /// Returns the processing instruction target and data if this node is a `.processingInstruction`.
    public var asProcessingInstruction: (target: String, data: String?)? {
        if case .processingInstruction(let target, let data) = self {
            return (target, data)
        }
        return nil
    }
}

extension XMLNode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .element(let elem):
            return elem.description
        case .comment(let text):
            return "<!--\(XMLWriter.sanitizeComment(text))-->"
        case .cdata(let text):
            return XMLWriter.escapeCData(text)
        case .text(let text):
            return XMLWriter.escapeText(text)
        case .processingInstruction(let target, let data):
            if let data {
                return "<?\(target) \(data)?>"
            }
            return "<?\(target)?>"
        }
    }
}
