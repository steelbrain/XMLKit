# XMLKit API Reference

## XMLElement

An XML element with a tag name, attributes, namespace info, and children.

```swift
public struct XMLElement: Hashable, Sendable, CustomStringConvertible
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Local name (without namespace prefix) |
| `prefix` | `String?` | Namespace prefix (e.g. `"h"` in `<h:table>`) |
| `namespace` | `String?` | Namespace URI this element belongs to |
| `namespaces` | `XMLNamespaceMap?` | Namespace declarations on this element (prefix → URI) |
| `attributes` | `[String: String]` | Attributes keyed by local name |
| `children` | `[XMLNode]` | Child nodes |
| `elementChildren` | `[XMLElement]` | Child elements only (filters out text, comments, etc.) |
| `description` | `String` | Compact XML string without declaration |

### Initializer

```swift
init(name: String)
```

Creates an empty element. All optional fields default to `nil`, attributes and children default to empty.

### Subscripts

```swift
subscript(name: String) -> XMLElement?
subscript(name: String, namespace namespace: String) -> XMLElement?
```

Shorthand for `getChild(_:)` and `getChild(_:namespace:)`.

### Child Access

```swift
func getChild(_ predicate: some XMLElementPredicate) -> XMLElement?
func getChild(_ name: String, namespace: String) -> XMLElement?
```

Returns the first child element matching the predicate.

```swift
mutating func withMutableChild<T>(_ predicate: some XMLElementPredicate, _ body: (inout XMLElement) -> T) -> T?
mutating func withMutableChild<T>(_ name: String, namespace: String, _ body: (inout XMLElement) -> T) -> T?
```

Finds a matching child and mutates it in place via a closure. Returns the closure's result, or `nil` if not found. Marked `@discardableResult`.

```swift
func indexOfChild(_ predicate: some XMLElementPredicate) -> Int?
func indexOfChild(_ name: String, namespace: String) -> Int?
```

Returns the index of the first matching child element in the `children` array.

```swift
mutating func takeChild(_ predicate: some XMLElementPredicate) -> XMLElement?
mutating func takeChild(_ name: String, namespace: String) -> XMLElement?
```

Removes and returns the first matching child element. Marked `@discardableResult`.

```swift
func getText() -> String?
```

Returns concatenated text and CDATA content of direct children. Returns `nil` if none found.

```swift
func matches(_ predicate: some XMLElementPredicate) -> Bool
func matches(_ name: String, namespace: String) -> Bool
```

Tests whether this element matches a predicate.

### Parsing

```swift
static func parse(_ string: String) throws -> XMLElement
static func parse<C: Collection>(_ bytes: C) throws -> XMLElement where C.Element == UInt8
static func parse(_ string: String, config: ParserConfig) throws -> XMLElement
static func parse<C: Collection>(_ bytes: C, config: ParserConfig) throws -> XMLElement where C.Element == UInt8
```

Parses XML and returns the first root element. Accepts `String` or UTF-8 bytes (e.g. `Data`). Throws `XMLParseError`.

```swift
static func parseAll(_ string: String) throws -> [XMLNode]
static func parseAll<C: Collection>(_ bytes: C) throws -> [XMLNode] where C.Element == UInt8
static func parseAll(_ string: String, config: ParserConfig) throws -> [XMLNode]
static func parseAll<C: Collection>(_ bytes: C, config: ParserConfig) throws -> [XMLNode] where C.Element == UInt8
```

Parses all top-level nodes (comments, PIs, elements). Throws `XMLParseError`.

### Writing

```swift
func write() -> String
func write(config: EmitterConfig) -> String
```

Serializes the element to an XML string.

### Builder DSL

```swift
static func build(_ name: String, attributes: [String: String] = [:], @XMLBuilder content: () -> [XMLNode]) -> XMLElement
static func build(_ name: String, attributes: [String: String] = [:]) -> XMLElement
```

Declarative element construction:

```swift
let doc = XMLElement.build("root") {
    XMLElement.build("child", attributes: ["id": "1"]) {
        "Text content"
    }
    XMLElement.build("empty")
}
```

---

## XMLNode

A node in an XML document tree.

```swift
public enum XMLNode: Hashable, Sendable, CustomStringConvertible
```

### Cases

| Case | Description |
|------|-------------|
| `.element(XMLElement)` | An XML element |
| `.comment(String)` | A comment (`<!-- ... -->`) |
| `.cdata(String)` | A CDATA section (`<![CDATA[ ... ]]>`) |
| `.text(String)` | A text node |
| `.processingInstruction(String, String?)` | A PI (`<?target data?>`) |

### Accessors

| Property | Returns |
|----------|---------|
| `asElement` | `XMLElement?` |
| `asComment` | `String?` |
| `asCData` | `String?` |
| `asText` | `String?` |
| `asProcessingInstruction` | `(target: String, data: String?)?` |

### Mutation

```swift
mutating func withElement<T>(_ body: (inout XMLElement) -> T) -> T?
```

Provides mutable access to the element via a closure. Returns `nil` for non-element nodes. Marked `@discardableResult`.

---

## XMLElementPredicate

Protocol for matching elements by name and/or namespace.

```swift
public protocol XMLElementPredicate: Sendable {
    func matches(_ element: XMLElement) -> Bool
}
```

### Built-in Conformances

- **`String`** — matches by local name (`element.name == self`)
- **`NameAndNamespace`** — matches by name and namespace URI

```swift
public struct NameAndNamespace: XMLElementPredicate {
    public init(name: String, namespace: String)
}
```

---

## XMLNamespaceMap

A mapping of namespace prefixes to URIs. An empty string key (`""`) represents the default namespace.

```swift
public struct XMLNamespaceMap: Equatable, Sendable, Hashable
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `mappings` | `[String: String]` | The underlying prefix-to-URI dictionary |
| `isEssentiallyEmpty` | `Bool` | `true` if empty or only contains the implicit `xml` namespace |

### Initializers

```swift
init()                           // Empty map
init(_ mappings: [String: String])  // From dictionary
```

### Access

```swift
subscript(prefix: String) -> String?          // Get/set by prefix
func uri(forPrefix prefix: String) -> String? // Get by prefix
```

---

## ParserConfig

Configuration options for the XML parser.

```swift
public struct ParserConfig: Sendable
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ignoreComments` | `Bool` | `false` | Omit comment nodes from the parsed tree |
| `ignoreProcessingInstructions` | `Bool` | `false` | Omit PI nodes from the parsed tree |

```swift
init(ignoreComments: Bool = false, ignoreProcessingInstructions: Bool = false)
```

---

## EmitterConfig

Configuration options for the XML writer.

```swift
public struct EmitterConfig: Sendable
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `writeDocumentDeclaration` | `Bool` | `true` | Emit `<?xml version="1.0" encoding="UTF-8"?>` |
| `performIndent` | `Bool` | `false` | Pretty-print with indentation |
| `indentString` | `String` | `"  "` | String per indent level |
| `lineSeparator` | `String` | `"\n"` | Line separator |

```swift
init(writeDocumentDeclaration: Bool = true, performIndent: Bool = false, indentString: String = "  ", lineSeparator: String = "\n")
```

---

## XMLParseError

Errors thrown during XML parsing.

```swift
public enum XMLParseError: Error, Equatable, Sendable, CustomStringConvertible
```

| Case | Description |
|------|-------------|
| `.malformedXML(String, line: Int, column: Int)` | Structural XML error with message and source location |
| `.cannotParse` | Unable to parse the document (e.g. no root element) |

---

## XMLBuilder

A result builder for declarative XML tree construction. Used via `XMLElement.build(_:content:)`.

Supports `XMLElement`, `XMLNode`, `String` literals, `if`/`else`, `for` loops, and optionals.
