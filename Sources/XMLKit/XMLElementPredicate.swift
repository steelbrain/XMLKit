/// A predicate for matching XML elements by name and/or namespace.
public protocol XMLElementPredicate: Sendable {
    /// Returns `true` if the given element matches this predicate.
    func matches(_ element: XMLElement) -> Bool
}

// MARK: - String conformance (match by local name)

extension String: XMLElementPredicate {
    public func matches(_ element: XMLElement) -> Bool {
        element.name == self
    }
}

/// A predicate that matches elements by both local name and namespace URI.
public struct NameAndNamespace: XMLElementPredicate {
    public let name: String
    public let namespace: String

    public init(name: String, namespace: String) {
        self.name = name
        self.namespace = namespace
    }

    public func matches(_ element: XMLElement) -> Bool {
        element.name == name && element.namespace == namespace
    }
}
