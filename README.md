# XMLKit

A pure-Swift XML parser and serializer with zero dependencies.

Parse XML into an in-memory tree, traverse and manipulate elements, and write it back to well-formed XML — all without Foundation or any third-party libraries.

## Features

- **Zero dependencies** — pure Swift, no Foundation XML classes, no C libraries
- **Parse XML** from `String` or `Data` into a traversable element tree
- **Write XML** back to a string with configurable formatting
- **Namespace-aware** — default namespaces, prefixed namespaces, undeclaration, shadowing
- **Full XML 1.0 support** — entities, CDATA, comments, processing instructions, DOCTYPE
- **Strict concurrency** — all types are `Sendable`, built with Swift 6.0 strict concurrency
- **Builder DSL** — construct XML trees declaratively with Swift result builders
- **Detailed error reporting** — parse errors include line and column numbers

## Installation

Add XMLKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/steelbrain/XMLKit.git", from: "0.1.0"),
]
```

Then add it as a dependency of your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["XMLKit"]
),
```

**Requirements:** Swift 6.0+, macOS 13+ / iOS 16+ / Linux

## Quick Start

### Parsing XML

```swift
import XMLKit

let xml = """
    <catalog>
        <book id="1">
            <title>Swift Programming</title>
            <author>Apple</author>
        </book>
        <book id="2">
            <title>XML Essentials</title>
        </book>
    </catalog>
    """

let catalog = try XMLElement.parse(xml)

// Access children by name
let firstBook = catalog.getChild("book")
print(firstBook?.attributes["id"])  // Optional("1")

// Subscript shorthand
let title = catalog["book"]?["title"]?.getText()
print(title)  // Optional("Swift Programming")
```

### Writing XML

```swift
let output = catalog.write()
// <?xml version="1.0" encoding="UTF-8"?>
// <catalog><book id="1"><title>Swift Programming</title>...

// Pretty-printed
let pretty = catalog.write(config: EmitterConfig(performIndent: true))
```

### Building XML with the DSL

```swift
let doc = XMLElement.build("catalog") {
    XMLElement.build("book", attributes: ["id": "1"]) {
        XMLElement.build("title") { "Swift Programming" }
        XMLElement.build("author") { "Apple" }
    }
    XMLElement.build("book", attributes: ["id": "2"]) {
        XMLElement.build("title") { "XML Essentials" }
    }
}
```

### Namespaces

```swift
let xml = """
    <root xmlns="urn:books" xmlns:dc="urn:dc">
        <dc:title>Example</dc:title>
    </root>
    """
let root = try XMLElement.parse(xml)
print(root.namespace)  // Optional("urn:books")

let title = root.getChild("title", namespace: "urn:dc")
print(title?.prefix)  // Optional("dc")
```

### Mutating the Tree

```swift
var root = try XMLElement.parse("<root><child name=\"old\"/></root>")

// Mutate a child in place
root.withMutableChild("child") { child in
    child.attributes["name"] = "new"
}

// Remove a child
let removed = root.takeChild("child")
```

### Error Handling

```swift
do {
    let elem = try XMLElement.parse("<root><unclosed>")
} catch let error as XMLParseError {
    print(error)
    // Malformed XML at 1:17: Unexpected end of input inside element <unclosed>
}
```

## API Reference

See [API.md](API.md) for the complete API reference.

## Acknowledgements

See [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).

## License

MIT
