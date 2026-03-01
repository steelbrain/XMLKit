/// Represents an XML element with a tag name, attributes, namespace info, and children.
public struct XMLElement: Hashable, Sendable {
    /// The local name of the element (without namespace prefix).
    public var name: String

    /// The namespace prefix, if any (e.g. `"h"` in `<h:table>`).
    public var prefix: String?

    /// The namespace URI this element belongs to, if any.
    public var namespace: String?

    /// The namespace declarations on this element (prefix -> URI).
    public var namespaces: XMLNamespaceMap?

    /// The element's attributes (local name -> value).
    public var attributes: [String: String]

    /// The child nodes of this element.
    public var children: [XMLNode]

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(prefix)
        hasher.combine(namespace)
        hasher.combine(namespaces)
        for key in attributes.keys.sorted() {
            hasher.combine(key)
            hasher.combine(attributes[key])
        }
        hasher.combine(children)
    }

    /// Creates a new empty element with the given name.
    public init(name: String) {
        self.name = name
        self.prefix = nil
        self.namespace = nil
        self.namespaces = nil
        self.attributes = [:]
        self.children = []
    }

    // MARK: - Computed Properties

    /// Returns only the child elements, filtering out text, comments, CDATA, and PIs.
    public var elementChildren: [XMLElement] {
        children.compactMap(\.asElement)
    }

    // MARK: - Subscript Access

    /// Returns the first child element with the given name.
    public subscript(name: String) -> XMLElement? {
        getChild(name)
    }

    /// Returns the first child element with the given name and namespace.
    public subscript(name: String, namespace namespace: String) -> XMLElement? {
        getChild(name, namespace: namespace)
    }

    // MARK: - Child Access

    /// Finds the first child element matching the given predicate.
    public func getChild(_ predicate: some XMLElementPredicate) -> XMLElement? {
        for child in children {
            if case .element(let elem) = child, predicate.matches(elem) {
                return elem
            }
        }
        return nil
    }

    /// Finds the first child element matching the given name and namespace.
    public func getChild(_ name: String, namespace: String) -> XMLElement? {
        getChild(NameAndNamespace(name: name, namespace: namespace))
    }

    /// Finds the first child element matching the predicate and mutates it via a closure.
    ///
    /// Returns the closure's result, or `nil` if no matching child was found.
    /// ```swift
    /// element.withMutableChild("name") { child in
    ///     child.attributes["suffix"] = "mr"
    /// }
    /// ```
    @discardableResult
    public mutating func withMutableChild<T>(
        _ predicate: some XMLElementPredicate,
        _ body: (inout XMLElement) -> T
    ) -> T? {
        guard let index = indexOfChild(predicate) else { return nil }
        return children[index].withElement(body)
    }

    /// Finds the first child element matching the name and namespace, and mutates it via a closure.
    @discardableResult
    public mutating func withMutableChild<T>(
        _ name: String, namespace: String,
        _ body: (inout XMLElement) -> T
    ) -> T? {
        withMutableChild(NameAndNamespace(name: name, namespace: namespace), body)
    }

    /// Returns the index of the first child element matching the predicate.
    public func indexOfChild(_ predicate: some XMLElementPredicate) -> Int? {
        for (index, child) in children.enumerated() {
            if case .element(let elem) = child, predicate.matches(elem) {
                return index
            }
        }
        return nil
    }

    /// Returns the index of the first child element matching the name and namespace.
    public func indexOfChild(_ name: String, namespace: String) -> Int? {
        indexOfChild(NameAndNamespace(name: name, namespace: namespace))
    }

    /// Removes and returns the first child element matching the predicate.
    @discardableResult
    public mutating func takeChild(_ predicate: some XMLElementPredicate) -> XMLElement? {
        guard let index = indexOfChild(predicate) else { return nil }
        let node = children.remove(at: index)
        if case .element(let elem) = node { return elem }
        return nil
    }

    /// Removes and returns the first child element matching the name and namespace.
    @discardableResult
    public mutating func takeChild(_ name: String, namespace: String) -> XMLElement? {
        takeChild(NameAndNamespace(name: name, namespace: namespace))
    }

    /// Returns the concatenated text and CDATA content of this element's direct children.
    ///
    /// Returns `nil` if there are no text or CDATA children.
    public func getText() -> String? {
        var result: String?
        for child in children {
            if let text = child.asText ?? child.asCData {
                if let existing = result {
                    result = existing + text
                } else {
                    result = text
                }
            }
        }
        return result
    }

    /// Returns `true` if this element matches the given predicate.
    public func matches(_ predicate: some XMLElementPredicate) -> Bool {
        predicate.matches(self)
    }

    /// Returns `true` if this element matches the given name and namespace.
    public func matches(_ name: String, namespace: String) -> Bool {
        matches(NameAndNamespace(name: name, namespace: namespace))
    }

    // MARK: - Parsing (convenience static methods)

    /// Parses an XML string into an `XMLElement` (the first root element found).
    public static func parse(_ string: String) throws -> XMLElement {
        try XMLParser.parse(string)
    }

    // swiftlint:disable optional_data_string_conversion

    /// Parses UTF-8 bytes into an `XMLElement`.
    public static func parse<C: Collection>(
        _ bytes: C
    ) throws -> XMLElement where C.Element == UInt8 {
        try parse(String(decoding: bytes, as: UTF8.self))
    }

    /// Parses an XML string with the given configuration.
    public static func parse(_ string: String, config: ParserConfig) throws -> XMLElement {
        try XMLParser.parse(string, config: config)
    }

    /// Parses UTF-8 bytes with the given configuration.
    public static func parse<C: Collection>(
        _ bytes: C, config: ParserConfig
    ) throws -> XMLElement where C.Element == UInt8 {
        try parse(String(decoding: bytes, as: UTF8.self), config: config)
    }

    /// Parses all top-level nodes from an XML string.
    public static func parseAll(_ string: String) throws -> [XMLNode] {
        try XMLParser.parseAll(string)
    }

    /// Parses all top-level nodes from UTF-8 bytes.
    public static func parseAll<C: Collection>(
        _ bytes: C
    ) throws -> [XMLNode] where C.Element == UInt8 {
        try parseAll(String(decoding: bytes, as: UTF8.self))
    }

    /// Parses all top-level nodes from an XML string with the given configuration.
    public static func parseAll(_ string: String, config: ParserConfig) throws -> [XMLNode] {
        try XMLParser.parseAll(string, config: config)
    }

    /// Parses all top-level nodes from UTF-8 bytes with the given configuration.
    public static func parseAll<C: Collection>(
        _ bytes: C, config: ParserConfig
    ) throws -> [XMLNode] where C.Element == UInt8 {
        try parseAll(String(decoding: bytes, as: UTF8.self), config: config)
    }

    // swiftlint:enable optional_data_string_conversion

    // MARK: - Builder

    /// Creates an element with the given name, attributes, and children built using the DSL.
    public static func build(
        _ name: String,
        attributes: [String: String] = [:],
        @XMLBuilder content: () -> [XMLNode]
    ) -> XMLElement {
        var element = XMLElement(name: name)
        element.attributes = attributes
        element.children = content()
        return element
    }

    /// Creates a leaf element with the given name and optional attributes (no children).
    public static func build(
        _ name: String,
        attributes: [String: String] = [:]
    ) -> XMLElement {
        var element = XMLElement(name: name)
        element.attributes = attributes
        return element
    }

    // MARK: - Writing

    /// Writes this element to an XML string with default configuration.
    public func write() -> String {
        XMLWriter.write(self)
    }

    /// Writes this element to an XML string with the given configuration.
    public func write(config: EmitterConfig) -> String {
        XMLWriter.write(self, config: config)
    }
}

extension XMLElement: CustomStringConvertible {
    public var description: String {
        write(config: EmitterConfig(writeDocumentDeclaration: false))
    }
}
