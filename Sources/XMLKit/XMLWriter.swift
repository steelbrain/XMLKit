/// Serializes an XML element tree back to an XML string.
enum XMLWriter {

    /// Writes an element with the default configuration.
    static func write(_ element: XMLElement) -> String {
        write(element, config: EmitterConfig())
    }

    /// Writes an element with the given configuration.
    static func write(_ element: XMLElement, config: EmitterConfig) -> String {
        var output = ""
        if config.writeDocumentDeclaration {
            output += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
            if config.performIndent {
                output += config.lineSeparator
            }
        }
        writeElement(element, to: &output, config: config, depth: 0, parentNamespaces: [:])
        return output
    }

    // MARK: - Element writing

    private static func writeElement(
        _ element: XMLElement,
        to output: inout String,
        config: EmitterConfig,
        depth: Int,
        parentNamespaces: [String: String]
    ) {
        if config.performIndent && depth > 0 {
            output += String(repeating: config.indentString, count: depth)
        }

        let tagName = qualifiedTagName(for: element)
        output += "<\(tagName)"

        let hasExplicitNamespaces = element.namespaces != nil
        let currentNamespaces = element.namespaces?.mappings ?? [:]
        writeNamespaceDeclarations(
            currentNamespaces, parentNamespaces: parentNamespaces,
            emitUndeclarations: hasExplicitNamespaces, to: &output
        )
        writeAttributes(element.attributes, to: &output)

        if element.children.isEmpty {
            output += " />"
            if config.performIndent {
                output += config.lineSeparator
            }
            return
        }

        output += ">"

        let allInline = element.children.allSatisfy { node in
            switch node {
            case .text, .cdata: return true
            default: return false
            }
        }

        if config.performIndent && !allInline {
            output += config.lineSeparator
        }

        // When namespaces is nil, the element has no explicit namespace info —
        // inherit parent namespaces so children don't emit spurious undeclarations.
        let mergedNamespaces: [String: String]
        if hasExplicitNamespaces {
            var merged = parentNamespaces.merging(currentNamespaces) { _, new in new }
            // Remove namespaces that were undeclared at this level so children
            // don't redundantly re-emit undeclarations.
            for key in parentNamespaces.keys where currentNamespaces[key] == nil && key != "xml" {
                merged.removeValue(forKey: key)
            }
            mergedNamespaces = merged
        } else {
            mergedNamespaces = parentNamespaces
        }
        writeChildren(
            element.children, to: &output, config: config,
            depth: depth, allInline: allInline, parentNamespaces: mergedNamespaces
        )

        if config.performIndent && !allInline {
            output += String(repeating: config.indentString, count: depth)
        }
        output += "</\(tagName)>"
        if config.performIndent {
            output += config.lineSeparator
        }
    }

    // MARK: - Helpers

    private static func qualifiedTagName(for element: XMLElement) -> String {
        if let prefix = element.prefix {
            return "\(prefix):\(element.name)"
        }
        return element.name
    }

    private static func writeNamespaceDeclarations(
        _ currentNamespaces: [String: String],
        parentNamespaces: [String: String],
        emitUndeclarations: Bool,
        to output: inout String
    ) {
        // Emit new or changed namespace declarations
        for prefix in currentNamespaces.keys.sorted() where currentNamespaces[prefix] != parentNamespaces[prefix] {
            guard let uri = currentNamespaces[prefix] else { continue }
            // The "xml" prefix is implicitly declared per the XML Namespaces spec
            if prefix == "xml" && uri == "http://www.w3.org/XML/1998/namespace" { continue }
            if prefix.isEmpty {
                output += " xmlns=\"\(escapeAttribute(uri))\""
            } else {
                output += " xmlns:\(prefix)=\"\(escapeAttribute(uri))\""
            }
        }
        // Emit undeclarations for parent namespaces removed in this scope.
        // Skip when the element has no explicit namespace info (namespaces is nil) —
        // in that case the element inherits parent namespaces, not undeclares them.
        guard emitUndeclarations else { return }
        for prefix in parentNamespaces.keys.sorted() {
            guard currentNamespaces[prefix] == nil && prefix != "xml" else { continue }
            if prefix.isEmpty {
                output += " xmlns=\"\""
            } else {
                output += " xmlns:\(prefix)=\"\""
            }
        }
    }

    private static func writeAttributes(
        _ attributes: [String: String],
        to output: inout String
    ) {
        for key in attributes.keys.sorted() {
            guard let value = attributes[key] else { continue }
            output += " \(key)=\"\(escapeAttribute(value))\""
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_parameter_count
    private static func writeChildren(
        _ children: [XMLNode],
        to output: inout String,
        config: EmitterConfig,
        depth: Int,
        allInline: Bool,
        parentNamespaces: [String: String]
    ) {
        for child in children {
            switch child {
            case .element(let childElem):
                writeElement(
                    childElem, to: &output, config: config,
                    depth: depth + 1, parentNamespaces: parentNamespaces
                )
            case .text(let text):
                if config.performIndent && !allInline {
                    output += String(repeating: config.indentString, count: depth + 1)
                }
                output += escapeText(text)
                if config.performIndent && !allInline {
                    output += config.lineSeparator
                }
            case .cdata(let text):
                if config.performIndent && !allInline {
                    output += String(repeating: config.indentString, count: depth + 1)
                }
                output += escapeCData(text)
                if config.performIndent && !allInline {
                    output += config.lineSeparator
                }
            case .comment(let text):
                if config.performIndent {
                    output += String(repeating: config.indentString, count: depth + 1)
                }
                output += "<!--\(sanitizeComment(text))-->"
                if config.performIndent {
                    output += config.lineSeparator
                }
            case .processingInstruction(let target, let data):
                if config.performIndent {
                    output += String(repeating: config.indentString, count: depth + 1)
                }
                if let data {
                    output += "<?\(target) \(data)?>"
                } else {
                    output += "<?\(target)?>"
                }
                if config.performIndent {
                    output += config.lineSeparator
                }
            }
        }
    }

    // MARK: - Escaping

    static func escapeText(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            default: result.append(ch)
            }
        }
        return result
    }

    /// Wraps text in a CDATA section, splitting at `]]>` boundaries to produce valid XML.
    ///
    /// `]]>` is forbidden inside CDATA, so `"a]]>b"` becomes `<![CDATA[a]]]]><![CDATA[>b]]>`.
    static func escapeCData(_ text: String) -> String {
        // Split on "]]>" without Foundation — scan for the 3-char sequence manually.
        let chars = Array(text)
        var parts: [String] = []
        var start = 0
        var i = 0
        while i < chars.count {
            if i + 2 < chars.count && chars[i] == "]" && chars[i + 1] == "]" && chars[i + 2] == ">" {
                parts.append(String(chars[start..<i]))
                i += 3
                start = i
            } else {
                i += 1
            }
        }
        parts.append(String(chars[start...]))

        return parts.enumerated().map { index, part in
            if index < parts.count - 1 {
                return "<![CDATA[\(part)]]]]><![CDATA[>"
            }
            return "<![CDATA[\(part)]]>"
        }.joined()
    }

    /// Sanitizes comment text so the output is valid XML.
    ///
    /// XML comments must not contain `--` and must not end with `-`.
    /// This inserts a space to break up any `--` sequence and appends
    /// a space if the text ends with `-`.
    static func sanitizeComment(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var lastWasHyphen = false
        for ch in text {
            if ch == "-" && lastWasHyphen {
                result.append(" -")
            } else {
                result.append(ch)
            }
            lastWasHyphen = ch == "-"
        }
        if result.hasSuffix("-") {
            result += " "
        }
        return result
    }

    private static func escapeAttribute(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default: result.append(ch)
            }
        }
        return result
    }
}
