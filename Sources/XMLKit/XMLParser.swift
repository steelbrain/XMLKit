/// Builds an XML element tree from a token stream.
enum XMLParser {

    /// Parses an XML string and returns the first root element.
    static func parse(_ string: String, config: ParserConfig = ParserConfig()) throws -> XMLElement {
        let nodes = try parseAll(string, config: config)
        for node in nodes {
            if case .element(let elem) = node {
                return elem
            }
        }
        throw XMLParseError.cannotParse
    }

    /// Parses an XML string and returns all top-level nodes.
    static func parseAll(
        _ string: String,
        config: ParserConfig = ParserConfig()
    ) throws -> [XMLNode] {
        var tokenizer = XMLTokenizer(string)
        let tokens = try tokenizer.tokenize()
        let positions = tokenizer.tokenPositions
        var context = BuilderContext(tokens: tokens, positions: positions, config: config)
        var nodes: [XMLNode] = []

        while context.cursor < tokens.count {
            if let node = try context.processTopLevelToken() {
                nodes.append(node)
            }
        }

        // Match xmltree-rs: a valid XML document must have at least one root element
        guard nodes.contains(where: { $0.asElement != nil }) else {
            throw XMLParseError.cannotParse
        }

        return nodes
    }
}

// MARK: - Builder Context

/// Internal mutable state for the tree-building pass.
private struct BuilderContext {
    let tokens: [XMLToken]
    let positions: [(line: Int, column: Int)]
    let config: ParserConfig
    var cursor: Int = 0
    var namespaceStack: [[String: String]] = [["xml": "http://www.w3.org/XML/1998/namespace"]]

    /// Processes a single top-level token, returning a node to append or nil if skipped.
    mutating func processTopLevelToken() throws -> XMLNode? {
        let token = tokens[cursor]
        switch token {
        case .startElement(let name, let prefix, let attrs, let nsDecls, let selfClosing):
            let element = try buildElement(
                name: name, prefix: prefix, attributes: attrs,
                namespaceDeclarations: nsDecls, selfClosing: selfClosing
            )
            return .element(element)

        case .comment(let text):
            cursor += 1
            return config.ignoreComments ? nil : .comment(text)

        case .text(let text):
            cursor += 1
            return .text(text)

        case .cdata(let text):
            cursor += 1
            return .cdata(text)

        case .processingInstruction(let target, let data):
            cursor += 1
            if target.lowercased() == "xml" { return nil }
            return config.ignoreProcessingInstructions ? nil : .processingInstruction(target, data)

        case .whitespace, .doctype, .endElement:
            cursor += 1
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    mutating func buildElement(
        name: String,
        prefix: String?,
        attributes: [String: String],
        namespaceDeclarations: [String: String],
        selfClosing: Bool
    ) throws -> XMLElement {
        let startCursor = cursor

        // Push namespace scope
        var currentScope = namespaceStack.last ?? [:]
        for (nsPrefix, uri) in namespaceDeclarations {
            if uri.isEmpty {
                // xmlns="" undeclares the default namespace
                currentScope.removeValue(forKey: nsPrefix)
            } else {
                currentScope[nsPrefix] = uri
            }
        }
        namespaceStack.append(currentScope)

        // Resolve this element's namespace
        let resolvedNamespace: String?
        if let prefix {
            guard let uri = currentScope[prefix] else {
                let pos = positions[startCursor]
                throw XMLParseError.malformedXML(
                    "Undeclared namespace prefix '\(prefix)'",
                    line: pos.line, column: pos.column
                )
            }
            resolvedNamespace = uri
        } else {
            resolvedNamespace = currentScope[""]
        }

        // Build namespace map for this element
        let nsMap = XMLNamespaceMap(currentScope)

        var element = XMLElement(name: name)
        element.prefix = prefix
        element.namespace = resolvedNamespace
        element.namespaces = nsMap
        element.attributes = attributes

        // Consume the startElement token
        cursor += 1

        if selfClosing {
            namespaceStack.removeLast()
            return element
        }

        // Read children until matching end element
        while cursor < tokens.count {
            let token = tokens[cursor]
            switch token {
            case .endElement(let endName, let endPrefix):
                if endName == name && endPrefix == prefix {
                    cursor += 1
                    namespaceStack.removeLast()
                    return element
                } else {
                    let pos = positions[cursor]
                    let expectedTag = prefix.map { "\($0):\(name)" } ?? name
                    let actualTag = endPrefix.map { "\($0):\(endName)" } ?? endName
                    throw XMLParseError.malformedXML(
                        "Expected closing tag '</\(expectedTag)>' but found '</\(actualTag)>'",
                        line: pos.line, column: pos.column
                    )
                }

            case .startElement(
                let childName, let childPrefix, let childAttrs,
                let childNsDecls, let childSelfClosing
            ):
                let child = try buildElement(
                    name: childName, prefix: childPrefix, attributes: childAttrs,
                    namespaceDeclarations: childNsDecls, selfClosing: childSelfClosing
                )
                element.children.append(.element(child))

            case .text(let text):
                element.children.append(.text(text))
                cursor += 1

            case .cdata(let text):
                element.children.append(.cdata(text))
                cursor += 1

            case .comment(let text):
                if !config.ignoreComments {
                    element.children.append(.comment(text))
                }
                cursor += 1

            case .processingInstruction(let target, let data):
                if !config.ignoreProcessingInstructions {
                    element.children.append(.processingInstruction(target, data))
                }
                cursor += 1

            case .whitespace, .doctype:
                cursor += 1
            }
        }

        let pos = positions[startCursor]
        throw XMLParseError.malformedXML(
            "Unexpected end of input inside element '\(name)'",
            line: pos.line, column: pos.column
        )
    }
}
