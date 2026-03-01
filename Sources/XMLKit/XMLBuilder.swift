/// A result builder for constructing XML element trees declaratively.
///
/// Supports `XMLNode`, `XMLElement` (auto-wrapped in `.element`), `String` (→ `.text`),
/// optionals, arrays, and `if`/`else` blocks.
///
/// ```swift
/// let doc = XMLElement.build("root") {
///     XMLElement.build("child", attributes: ["id": "1"]) {
///         "Text content"
///     }
///     XMLElement.build("empty")
/// }
/// ```
@resultBuilder
public enum XMLBuilder {
    public static func buildBlock(_ components: [XMLNode]...) -> [XMLNode] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ element: XMLElement) -> [XMLNode] {
        [.element(element)]
    }

    public static func buildExpression(_ node: XMLNode) -> [XMLNode] {
        [node]
    }

    public static func buildExpression(_ text: String) -> [XMLNode] {
        [.text(text)]
    }

    public static func buildOptional(_ component: [XMLNode]?) -> [XMLNode] {
        component ?? []
    }

    public static func buildEither(first component: [XMLNode]) -> [XMLNode] {
        component
    }

    public static func buildEither(second component: [XMLNode]) -> [XMLNode] {
        component
    }

    public static func buildArray(_ components: [[XMLNode]]) -> [XMLNode] {
        components.flatMap { $0 }
    }
}
