// swiftlint:disable file_length

/// A token produced by the XML tokenizer.
enum XMLToken: Equatable, Sendable {
    /// An element opening tag with its name, namespace prefix, attributes, namespace declarations,
    /// and whether it is self-closing.
    case startElement(
        name: String,
        prefix: String?,
        attributes: [String: String],
        namespaceDeclarations: [String: String],
        selfClosing: Bool
    )
    /// A closing tag with its name and namespace prefix.
    case endElement(name: String, prefix: String?)
    /// Character data (text content) — already entity-decoded.
    case text(String)
    /// A CDATA section.
    case cdata(String)
    /// A comment.
    case comment(String)
    /// A processing instruction.
    case processingInstruction(target: String, data: String?)
    /// Whitespace-only text.
    case whitespace(String)
    /// A DOCTYPE declaration (content is ignored).
    case doctype
}

// swiftlint:disable type_body_length

/// A character-by-character XML tokenizer.
///
/// Produces a sequence of `XMLToken` values from an XML string.
struct XMLTokenizer {
    private let source: [Character]
    private var position: Int = 0
    private var tokens: [XMLToken] = []
    private var line: Int = 1
    private var column: Int = 1

    /// Source positions corresponding to each token (line, column at token start).
    private(set) var tokenPositions: [(line: Int, column: Int)] = []

    init(_ string: String) {
        // XML 1.0 §2.11: Normalize line endings before parsing.
        // \r\n → \n, standalone \r → \n.
        // Swift treats \r\n as a single Character (extended grapheme cluster),
        // so we can normalize during the Array conversion.
        var chars = Array(string).map { ch -> Character in
            if ch == "\r\n" || ch == "\r" { return Character("\n") }
            return ch
        }
        // Strip UTF-8 BOM (U+FEFF) if present at the start of the document.
        if chars.first == "\u{FEFF}" {
            chars.removeFirst()
        }
        self.source = chars
    }

    /// Tokenize the entire source and return all tokens.
    mutating func tokenize() throws -> [XMLToken] {
        tokens = []
        tokenPositions = []
        position = 0
        line = 1
        column = 1
        while position < source.count {
            if current == "<" {
                try readMarkup()
            } else {
                try readText()
            }
        }
        return tokens
    }

    // MARK: - Character access helpers

    private var current: Character {
        source[position]
    }

    private func peek(_ offset: Int = 1) -> Character? {
        let idx = position + offset
        return idx < source.count ? source[idx] : nil
    }

    private mutating func advance(_ count: Int = 1) {
        for _ in 0..<count {
            guard position < source.count else { return }
            if source[position] == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            position += 1
        }
    }

    private func remaining() -> Int {
        source.count - position
    }

    private func startsWith(_ prefix: String) -> Bool {
        let chars = Array(prefix)
        guard position + chars.count <= source.count else { return false }
        for (i, ch) in chars.enumerated() where source[position + i] != ch {
            return false
        }
        return true
    }

    private func makeError(_ message: String) -> XMLParseError {
        .malformedXML(message, line: line, column: column)
    }

    // MARK: - Text

    private mutating func readText() throws {
        let startLine = line
        let startColumn = column
        var text = ""
        while position < source.count && current != "<" {
            if current == "&" {
                text += try decodeEntity()
            } else {
                // XML 1.0 §2.4: "]]>" must not appear in character data
                if current == ">" && text.hasSuffix("]]") {
                    throw makeError(
                        "Character sequence ']]>' is not allowed in text content"
                    )
                }
                text.append(current)
                advance()
            }
        }
        if !text.isEmpty {
            if text.allSatisfy(\.isWhitespace) {
                tokenPositions.append((line: startLine, column: startColumn))
                tokens.append(.whitespace(text))
            } else {
                tokenPositions.append((line: startLine, column: startColumn))
                tokens.append(.text(text))
            }
        }
    }

    // MARK: - Entity decoding

    // swiftlint:disable:next cyclomatic_complexity
    private mutating func decodeEntity() throws -> String {
        guard current == "&" else { return "" }
        let entityLine = line
        let entityColumn = column
        // Skip '&'
        advance()
        var entityName = ""
        while position < source.count && current != ";" {
            entityName.append(current)
            advance()
        }
        guard position < source.count else {
            throw XMLParseError.malformedXML(
                "Unterminated entity reference '&\(entityName)'",
                line: entityLine, column: entityColumn
            )
        }
        // Skip ';'
        advance()
        // Named entities
        switch entityName {
        case "lt": return "<"
        case "gt": return ">"
        case "amp": return "&"
        case "quot": return "\""
        case "apos": return "'"
        default: break
        }
        // Numeric character references
        if entityName.hasPrefix("#x") || entityName.hasPrefix("#X") {
            let hex = String(entityName.dropFirst(2))
            if let cp = UInt32(hex, radix: 16), let sc = Unicode.Scalar(cp), XMLNameChars.isValidXMLChar(sc) {
                return String(Character(sc))
            }
            throw XMLParseError.malformedXML(
                "Invalid numeric character reference '&\(entityName);'",
                line: entityLine, column: entityColumn
            )
        } else if entityName.hasPrefix("#") {
            let decimal = String(entityName.dropFirst(1))
            if let cp = UInt32(decimal, radix: 10), let sc = Unicode.Scalar(cp), XMLNameChars.isValidXMLChar(sc) {
                return String(Character(sc))
            }
            throw XMLParseError.malformedXML(
                "Invalid numeric character reference '&\(entityName);'",
                line: entityLine, column: entityColumn
            )
        }
        // Unknown entity
        throw XMLParseError.malformedXML(
            "Unknown entity reference '&\(entityName);'",
            line: entityLine, column: entityColumn
        )
    }

    // MARK: - Markup dispatcher

    private mutating func readMarkup() throws {
        assert(current == "<")
        if startsWith("<!--") {
            try readComment()
        } else if startsWith("<![CDATA[") {
            try readCData()
        } else if startsWith("<!DOCTYPE") {
            try readDoctype()
        } else if startsWith("<?") {
            try readProcessingInstruction()
        } else if startsWith("</") {
            try readEndElement()
        } else {
            try readStartElement()
        }
    }

    // MARK: - Comment

    private mutating func readComment() throws {
        let startLine = line
        let startColumn = column
        // Skip '<!--'
        advance(4)
        var content = ""
        var lastWasHyphen = false
        while position < source.count {
            if startsWith("-->") {
                advance(3)
                tokenPositions.append((line: startLine, column: startColumn))
                tokens.append(.comment(content))
                return
            }
            // XML 1.0 §2.5: comments must not contain "--"
            if current == "-" && lastWasHyphen {
                throw XMLParseError.malformedXML(
                    "Comments must not contain '--'",
                    line: line, column: column - 1
                )
            }
            lastWasHyphen = current == "-"
            content.append(current)
            advance()
        }
        throw makeError("Unterminated comment")
    }

    // MARK: - CDATA

    private mutating func readCData() throws {
        let startLine = line
        let startColumn = column
        // Skip '<![CDATA['
        advance(9)
        var content = ""
        while position < source.count {
            if startsWith("]]>") {
                advance(3)
                tokenPositions.append((line: startLine, column: startColumn))
                tokens.append(.cdata(content))
                return
            }
            content.append(current)
            advance()
        }
        throw makeError("Unterminated CDATA section")
    }

    // MARK: - DOCTYPE

    // swiftlint:disable:next cyclomatic_complexity
    private mutating func readDoctype() throws {
        let startLine = line
        let startColumn = column
        // Skip '<!DOCTYPE'
        advance(9)
        var depth = 1
        var inSingleQuote = false
        var inDoubleQuote = false
        while position < source.count && depth > 0 {
            let ch = current
            if inSingleQuote {
                if ch == "'" { inSingleQuote = false }
            } else if inDoubleQuote {
                if ch == "\"" { inDoubleQuote = false }
            } else {
                switch ch {
                case "'": inSingleQuote = true
                case "\"": inDoubleQuote = true
                case "<": depth += 1
                case ">": depth -= 1
                default: break
                }
            }
            advance()
        }
        guard depth == 0 else {
            throw XMLParseError.malformedXML(
                "Unterminated DOCTYPE declaration",
                line: startLine, column: startColumn
            )
        }
        tokenPositions.append((line: startLine, column: startColumn))
        tokens.append(.doctype)
    }

    // MARK: - Processing Instruction

    private mutating func readProcessingInstruction() throws {
        let startLine = line
        let startColumn = column
        // Skip '<?'
        advance(2)
        skipWhitespace()
        let target = readName()
        if target.isEmpty {
            throw makeError("Empty processing instruction target")
        }
        skipWhitespace()
        var data = ""
        while position < source.count {
            if startsWith("?>") {
                advance(2)
                let trimmed = data.isEmpty ? nil : data
                tokenPositions.append((line: startLine, column: startColumn))
                tokens.append(.processingInstruction(target: target, data: trimmed))
                return
            }
            data.append(current)
            advance()
        }
        throw makeError("Unterminated processing instruction")
    }

    // MARK: - Start Element

    private mutating func readStartElement() throws {
        let startLine = line
        let startColumn = column
        // Skip '<'
        advance()
        skipWhitespace()
        let fullName = readName()
        if fullName.isEmpty {
            throw makeError("Empty element name")
        }

        let (prefix, localName) = splitQName(fullName)
        var attributes: [String: String] = [:]
        var nsDeclarations: [String: String] = [:]
        try readAttributes(into: &attributes, namespaces: &nsDeclarations)

        var selfClosing = false
        if position < source.count && current == "/" {
            selfClosing = true
            advance()
        }
        if position < source.count && current == ">" {
            advance()
        } else {
            throw makeError(
                "Expected '>' at end of start tag '\(localName)'"
            )
        }

        tokenPositions.append((line: startLine, column: startColumn))
        tokens.append(
            .startElement(
                name: localName,
                prefix: prefix,
                attributes: attributes,
                namespaceDeclarations: nsDeclarations,
                selfClosing: selfClosing
            )
        )
    }

    private mutating func readAttributes(
        into attributes: inout [String: String],
        namespaces nsDeclarations: inout [String: String]
    ) throws {
        while position < source.count {
            skipWhitespace()
            if position >= source.count { break }
            if current == "/" || current == ">" { break }

            let attrFullName = readName()
            if attrFullName.isEmpty { break }

            skipWhitespace()
            guard position < source.count && current == "=" else {
                throw makeError(
                    "Expected '=' after attribute name '\(attrFullName)'"
                )
            }
            // Skip '='
            advance()
            skipWhitespace()

            let value = try readAttributeValue()

            // Check if it's a namespace declaration
            if attrFullName == "xmlns" {
                nsDeclarations[""] = value
            } else if attrFullName.hasPrefix("xmlns:") {
                let nsPrefix = String(attrFullName.dropFirst(6))
                nsDeclarations[nsPrefix] = value
            } else {
                // Discard attribute prefix (store only local name), matching xmltree-rs behavior
                let (_, attrLocal) = splitQName(attrFullName)
                if attributes[attrLocal] != nil {
                    throw makeError("Duplicate attribute '\(attrLocal)'")
                }
                attributes[attrLocal] = value
            }
        }
    }

    // MARK: - End Element

    private mutating func readEndElement() throws {
        let startLine = line
        let startColumn = column
        // Skip '</'
        advance(2)
        skipWhitespace()
        let fullName = readName()
        if fullName.isEmpty {
            throw makeError("Empty end tag name")
        }
        let (prefix, localName) = splitQName(fullName)
        skipWhitespace()
        guard position < source.count && current == ">" else {
            throw makeError(
                "Expected '>' at end of closing tag '\(localName)'"
            )
        }
        advance()
        tokenPositions.append((line: startLine, column: startColumn))
        tokens.append(.endElement(name: localName, prefix: prefix))
    }

    // MARK: - Attribute value

    private mutating func readAttributeValue() throws -> String {
        guard position < source.count else {
            throw makeError("Unexpected end of input reading attribute value")
        }
        let quote = current
        guard quote == "\"" || quote == "'" else {
            throw makeError(
                "Expected quote for attribute value, got '\(current)'"
            )
        }
        // Skip opening quote
        advance()
        var value = ""
        while position < source.count && current != quote {
            if current == "<" {
                throw makeError(
                    "Character '<' is not allowed in attribute values"
                )
            } else if current == "&" {
                value += try decodeEntity()
            } else if current == "\r\n" || current == "\r" || current == "\n" || current == "\t" {
                // XML 1.0 §3.3.3: normalize whitespace to space
                // Note: Swift treats \r\n as a single Character (grapheme cluster)
                value.append(" ")
                advance()
            } else {
                value.append(current)
                advance()
            }
        }
        guard position < source.count else {
            throw makeError("Unterminated attribute value")
        }
        // Skip closing quote
        advance()
        return value
    }

    // MARK: - Helpers

    private mutating func skipWhitespace() {
        while position < source.count && current.isWhitespace {
            advance()
        }
    }

    private mutating func readName() -> String {
        var name = ""
        guard position < source.count && isNameStartChar(current) else { return name }
        name.append(current)
        advance()
        while position < source.count && isNameChar(current) {
            name.append(current)
            advance()
        }
        return name
    }

    private func isNameStartChar(_ ch: Character) -> Bool {
        XMLNameChars.isNameStartChar(ch)
    }

    private func isNameChar(_ ch: Character) -> Bool {
        XMLNameChars.isNameChar(ch)
    }

    /// Splits a qualified name like `"h:table"` into `("h", "table")`.
    /// For unprefixed names, returns `(nil, name)`.
    private func splitQName(_ qname: String) -> (String?, String) {
        guard let colonIdx = qname.firstIndex(of: ":") else {
            return (nil, qname)
        }
        let prefix = String(qname[qname.startIndex..<colonIdx])
        let local = String(qname[qname.index(after: colonIdx)...])
        return (prefix, local)
    }
}
// swiftlint:enable type_body_length
