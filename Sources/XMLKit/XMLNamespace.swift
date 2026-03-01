/// A mapping of namespace prefixes to URIs.
///
/// An empty string key represents the default namespace.
public struct XMLNamespaceMap: Equatable, Sendable, Hashable {
    /// The underlying prefix-to-URI dictionary.
    public var mappings: [String: String]

    /// Creates an empty namespace map.
    public init() {
        self.mappings = [:]
    }

    /// Creates a namespace map from a dictionary.
    public init(_ mappings: [String: String]) {
        self.mappings = mappings
    }

    /// Returns `true` if the map has no meaningful namespace mappings.
    ///
    /// A map is "essentially empty" if its only entry is the default XML namespace.
    public var isEssentiallyEmpty: Bool {
        if mappings.isEmpty {
            return true
        }
        if mappings.count == 1, mappings["xml"] == "http://www.w3.org/XML/1998/namespace" {
            return true
        }
        return false
    }

    /// Look up the URI for a given prefix.
    public subscript(prefix: String) -> String? {
        get { mappings[prefix] }
        set { mappings[prefix] = newValue }
    }

    /// Returns the URI for the given prefix, if any.
    public func uri(forPrefix prefix: String) -> String? {
        mappings[prefix]
    }
}
