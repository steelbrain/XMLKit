import Testing

@testable import XMLKit

@Suite("XMLWriter — Namespace Tests")
struct XMLWriterNamespaceTests {

    @Test("Namespace declarations are not repeated for children")
    func testNamespaceDedup() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        let ns = XMLNamespaceMap(["": "urn:test", "xml": "http://www.w3.org/XML/1998/namespace"])
        var root = XMLElement(name: "root")
        root.namespace = "urn:test"
        root.namespaces = ns
        var child = XMLElement(name: "child")
        child.namespace = "urn:test"
        child.namespaces = ns
        root.children = [.element(child)]
        let output = root.write(config: config)

        // xmlns="urn:test" should appear once (on root), not on child
        let count = output.components(separatedBy: "xmlns=\"urn:test\"").count - 1
        #expect(count == 1)
    }

    @Test("Prefixed namespace elements are written with prefix")
    func testPrefixedNS() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "data")
        root.prefix = "p"
        root.namespace = "urn:example"
        root.namespaces = XMLNamespaceMap([
            "p": "urn:example",
            "xml": "http://www.w3.org/XML/1998/namespace",
        ])
        let output = root.write(config: config)
        #expect(output.contains("<p:data"))
        #expect(output.contains("xmlns:p=\"urn:example\""))
    }

    @Test("Namespace undeclaration is preserved on write")
    func testNamespaceUndeclarationWrite() throws {
        let xml = """
            <root xmlns="urn:default">
                <child xmlns="">
                    <grandchild/>
                </child>
            </root>
            """
        let root = try XMLElement.parse(xml)
        let config = EmitterConfig(writeDocumentDeclaration: false)
        let output = root.write(config: config)

        // The output must contain xmlns="" to undeclare the default namespace
        #expect(output.contains("xmlns=\"\""))

        // Round-trip: parsing the output should give the same namespace structure
        let reparsed = try XMLElement.parse(output)
        #expect(reparsed.namespace == "urn:default")
        #expect(reparsed.getChild("child")?.namespace == nil)
        #expect(reparsed.getChild("child")?.getChild("grandchild")?.namespace == nil)
    }

    @Test("Namespace undeclaration is not redundantly repeated on children")
    func testNamespaceUndeclarationNotRepeated() throws {
        let xml = """
            <root xmlns="urn:default">
                <child xmlns="">
                    <grandchild/>
                    <grandchild2/>
                </child>
            </root>
            """
        let root = try XMLElement.parse(xml)
        let config = EmitterConfig(writeDocumentDeclaration: false)
        let output = root.write(config: config)

        // xmlns="" should appear exactly once (on child), not on grandchildren
        var searchRange = output.startIndex..<output.endIndex
        var undeclCount = 0
        while let range = output.range(of: "xmlns=\"\"", range: searchRange) {
            undeclCount += 1
            searchRange = range.upperBound..<output.endIndex
        }
        #expect(undeclCount == 1)
    }

    @Test("The xml namespace is not emitted in output")
    func testNoXmlnsXml() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "root")
        root.namespace = "urn:test"
        root.namespaces = XMLNamespaceMap([
            "": "urn:test",
            "xml": "http://www.w3.org/XML/1998/namespace",
        ])
        let output = root.write(config: config)
        #expect(!output.contains("xmlns:xml"))
        #expect(output.contains("xmlns=\"urn:test\""))
    }

    @Test("Adding a programmatic child to a namespaced tree does not emit spurious undeclarations")
    func testProgrammaticChildNoSpuriousUndecl() throws {
        var root = try XMLElement.parse(
            "<root xmlns=\"urn:ns\"><existing/></root>"
        )
        let newChild = XMLElement(name: "added")
        root.children.append(.element(newChild))

        let config = EmitterConfig(writeDocumentDeclaration: false)
        let output = root.write(config: config)

        // The new child should NOT get xmlns="" since it has no explicit namespace info
        #expect(!output.contains("<added xmlns=\"\""))
        #expect(output.contains("<added"))
    }

    @Test("Multiple namespace prefixes are all declared in output")
    func testMultipleNamespacePrefixes() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "data")
        root.prefix = "p"
        root.namespace = "urn:primary"
        root.namespaces = XMLNamespaceMap([
            "p": "urn:primary",
            "s": "urn:secondary",
            "xml": "http://www.w3.org/XML/1998/namespace",
        ])
        var child1 = XMLElement(name: "item")
        child1.prefix = "p"
        child1.namespace = "urn:primary"
        child1.namespaces = root.namespaces
        var child2 = XMLElement(name: "item")
        child2.prefix = "s"
        child2.namespace = "urn:secondary"
        child2.namespaces = root.namespaces
        root.children = [.element(child1), .element(child2)]

        let output = root.write(config: config)
        #expect(output.contains("xmlns:p=\"urn:primary\""))
        #expect(output.contains("xmlns:s=\"urn:secondary\""))
        #expect(output.contains("<p:data"))
        #expect(output.contains("<p:item"))
        #expect(output.contains("<s:item"))
    }

    @Test("Adding a programmatic child to a prefixed-namespace tree does not emit spurious undeclarations")
    func testProgrammaticChildNoPrefixUndecl() throws {
        var root = try XMLElement.parse(
            "<h:root xmlns:h=\"urn:html\"><h:item/></h:root>"
        )
        let newChild = XMLElement(name: "plain")
        root.children.append(.element(newChild))

        let config = EmitterConfig(writeDocumentDeclaration: false)
        let output = root.write(config: config)

        // The new child should NOT get xmlns:h=""
        #expect(!output.contains("xmlns:h=\"\""))
        #expect(output.contains("<plain"))
    }
}
