import Foundation
import Testing

@testable import XMLKit

@Suite("XMLParser — Spec Compliance Tests")
struct XMLParserSpecTests {

    // MARK: - Config default values

    @Test("ParserConfig defaults")
    func testParserConfigDefaults() {
        let config = ParserConfig()
        #expect(config.ignoreComments == false)
        #expect(config.ignoreProcessingInstructions == false)
    }

    @Test("EmitterConfig defaults")
    func testEmitterConfigDefaults() {
        let config = EmitterConfig()
        #expect(config.writeDocumentDeclaration == true)
        #expect(config.performIndent == false)
        #expect(config.indentString == "  ")
        #expect(config.lineSeparator == "\n")
    }

    // MARK: - Spec compliance

    @Test("Mismatched prefix on closing tag throws")
    func testMismatchedPrefix() throws {
        let xml = "<h:root xmlns:h=\"urn:h\" xmlns:f=\"urn:f\"></f:root>"
        #expect {
            _ = try XMLElement.parse(xml)
        } throws: { error in
            guard let parseError = error as? XMLParseError,
                case .malformedXML(let msg, _, _) = parseError
            else { return false }
            return msg.contains("h:root") && msg.contains("f:root")
        }
    }

    @Test("Namespace undeclaration with xmlns=\"\"")
    func testNamespaceUndeclaration() throws {
        let xml = """
            <root xmlns="urn:default">
                <child xmlns="">
                    <grandchild/>
                </child>
            </root>
            """
        let root = try XMLElement.parse(xml)
        #expect(root.namespace == "urn:default")
        let child = root.getChild("child")
        #expect(child != nil)
        #expect(child?.namespace == nil)
        let grandchild = child?.getChild("grandchild")
        #expect(grandchild != nil)
        #expect(grandchild?.namespace == nil)
    }

    @Test("Unknown entity reference throws during parse")
    func testUnknownEntity() throws {
        let xml = "<root>&foo;</root>"
        #expect(throws: XMLParseError.self) {
            _ = try XMLElement.parse(xml)
        }
    }

    @Test("Parse from Data with config")
    func testParseDataWithConfig() throws {
        let xml = "<root><!-- comment --><child/></root>"
        let data = Data(xml.utf8)
        let config = ParserConfig(ignoreComments: true)
        let elem = try XMLElement.parse(data, config: config)
        // Comment should be filtered out
        #expect(elem.children.count == 1)
        #expect(elem.children[0].asElement?.name == "child")
    }

    @Test("ParseAll from Data with config")
    func testParseAllDataWithConfig() throws {
        let xml = "<!-- before --><root/>"
        let data = Data(xml.utf8)
        let config = ParserConfig(ignoreComments: true)
        let nodes = try XMLElement.parseAll(data, config: config)
        // Comment should be filtered out, only root element
        #expect(nodes.count == 1)
        #expect(nodes[0].asElement?.name == "root")
    }

    @Test("Literal < in attribute value is rejected")
    func testLessThanInAttribute() throws {
        let xml = "<root attr=\"a<b\"/>"
        #expect(throws: XMLParseError.self) {
            _ = try XMLElement.parse(xml)
        }
    }

    @Test("Attribute value whitespace is normalized")
    func testAttributeWhitespaceNormalized() throws {
        let xml = "<root attr=\"a\tb\nc\"/>"
        let elem = try XMLElement.parse(xml)
        #expect(elem.attributes["attr"] == "a b c")
    }

    @Test("Undeclared namespace prefix throws error")
    func testUndeclaredPrefix() throws {
        let xml = "<h:root><child/></h:root>"
        #expect {
            _ = try XMLElement.parse(xml)
        } throws: { error in
            guard let parseError = error as? XMLParseError,
                case .malformedXML(let msg, _, _) = parseError
            else { return false }
            return msg.contains("Undeclared namespace prefix") && msg.contains("h")
        }
    }

    @Test("Line endings are normalized before parsing")
    func testLineEndingNormalization() throws {
        let xml = "<root>hello\r\nworld</root>"
        let elem = try XMLElement.parse(xml)
        let text = elem.getText()
        #expect(text == "hello\nworld")
        #expect(text?.contains("\r") != true)
    }

    @Test("Standalone CR is normalized to LF in parsed text")
    func testStandaloneCRNormalization() throws {
        let xml = "<root>hello\rworld</root>"
        let elem = try XMLElement.parse(xml)
        let text = elem.getText()
        #expect(text == "hello\nworld")
    }

    @Test("Namespace undeclaration round-trip preserves semantics")
    func testNamespaceUndeclarationRoundTrip() throws {
        let xml = """
            <root xmlns="urn:ns">
                <child xmlns="">
                    <grandchild/>
                </child>
            </root>
            """
        let elem1 = try XMLElement.parse(xml)
        let output = elem1.write()
        let elem2 = try XMLElement.parse(output)

        #expect(elem1.namespace == elem2.namespace)
        #expect(elem1.getChild("child")?.namespace == elem2.getChild("child")?.namespace)
        #expect(
            elem1.getChild("child")?.getChild("grandchild")?.namespace
                == elem2.getChild("child")?.getChild("grandchild")?.namespace
        )
    }

    // MARK: - Namespace shadowing and restoration

    @Test("Namespace prefix is shadowed in child scope")
    func testNamespaceShadowing() throws {
        let xml = """
            <root xmlns:a="urn:a">
                <child xmlns:a="urn:b">
                    <inner/>
                </child>
            </root>
            """
        let root = try XMLElement.parse(xml)
        #expect(root.namespace == nil)
        let child = root.getChild("child")
        #expect(child != nil)
        #expect(child?.namespaces?.mappings["a"] == "urn:b")
        let inner = child?.getChild("inner")
        #expect(inner?.namespaces?.mappings["a"] == "urn:b")
    }

    @Test("Namespace prefix is restored in sibling after shadowing child")
    func testNamespaceRestoration() throws {
        let xml = """
            <root xmlns:a="urn:a">
                <child xmlns:a="urn:b"/>
                <sibling a:attr="val"/>
            </root>
            """
        let root = try XMLElement.parse(xml)
        let child = root.getChild("child")
        #expect(child?.namespaces?.mappings["a"] == "urn:b")
        let sibling = root.getChild("sibling")
        // Sibling should see the original "a" mapping from root, not the override
        #expect(sibling?.namespaces?.mappings["a"] == "urn:a")
    }

    @Test("Namespace shadowing round-trip")
    func testNamespaceShadowingRoundTrip() throws {
        let xml = """
            <root xmlns:a="urn:a">
                <child xmlns:a="urn:b">
                    <inner/>
                </child>
            </root>
            """
        let elem1 = try XMLElement.parse(xml)
        let output = elem1.write()
        let elem2 = try XMLElement.parse(output)
        #expect(elem1 == elem2)
    }

    // MARK: - Single-quoted attributes at parser level

    @Test("Single-quoted attributes are parsed correctly")
    func testSingleQuotedAttributes() throws {
        let xml = "<root attr='hello' other='world'/>"
        let elem = try XMLElement.parse(xml)
        #expect(elem.attributes["attr"] == "hello")
        #expect(elem.attributes["other"] == "world")
    }

    // MARK: - Empty attribute values at parser level

    @Test("Empty attribute values are preserved")
    func testEmptyAttributeValues() throws {
        let xml = "<root empty=\"\" also=''/>"
        let elem = try XMLElement.parse(xml)
        #expect(elem.attributes["empty"] == "")
        #expect(elem.attributes["also"] == "")
    }

    // MARK: - Unicode and international characters

    @Test("CJK element names are parsed correctly")
    func testCJKElementNames() throws {
        let xml = "<\u{65E5}\u{672C}\u{8A9E}>\u{30C6}\u{30B9}\u{30C8}</\u{65E5}\u{672C}\u{8A9E}>"
        let elem = try XMLElement.parse(xml)
        #expect(elem.name == "\u{65E5}\u{672C}\u{8A9E}")
        #expect(elem.getText() == "\u{30C6}\u{30B9}\u{30C8}")
    }

    @Test("Non-ASCII attribute values are preserved")
    func testNonASCIIAttributeValues() throws {
        let xml = "<root attr=\"caf\u{00E9}\"/>"
        let elem = try XMLElement.parse(xml)
        #expect(elem.attributes["attr"] == "caf\u{00E9}")
    }

    @Test("Unicode element names round-trip")
    func testUnicodeRoundTrip() throws {
        let xml = "<\u{00E9}l\u{00E9}ment>contenu</\u{00E9}l\u{00E9}ment>"
        let elem1 = try XMLElement.parse(xml)
        let output = elem1.write()
        let elem2 = try XMLElement.parse(output)
        #expect(elem1 == elem2)
    }

    @Test("Accented characters in text content")
    func testAccentedTextContent() throws {
        let xml = "<root>\u{00FC}\u{00F6}\u{00E4}\u{00DF}</root>"
        let elem = try XMLElement.parse(xml)
        #expect(elem.getText() == "\u{00FC}\u{00F6}\u{00E4}\u{00DF}")
    }

    // MARK: - Deep nesting

    @Test("Deeply nested elements parse and round-trip successfully")
    func testDeepNesting() throws {
        // Note: The recursive parser has a practical depth limit due to stack size.
        // 100 levels is well within safe limits for typical use.
        let depth = 100
        var xml = ""
        for i in 0..<depth {
            xml += "<level\(i)>"
        }
        xml += "leaf"
        for i in stride(from: depth - 1, through: 0, by: -1) {
            xml += "</level\(i)>"
        }
        let elem = try XMLElement.parse(xml)
        #expect(elem.name == "level0")

        // Walk down to the leaf
        var current = elem
        for i in 1..<depth {
            guard let child = current.getChild("level\(i)") else {
                Issue.record("Missing child at depth \(i)")
                return
            }
            current = child
        }
        #expect(current.getText() == "leaf")

        // Round-trip
        let output = elem.write()
        let elem2 = try XMLElement.parse(output)
        #expect(elem == elem2)
    }

    // MARK: - BOM handling at parser level

    @Test("UTF-8 BOM before document is handled")
    func testBOMHandling() throws {
        let xml = "\u{FEFF}<root><child/></root>"
        let elem = try XMLElement.parse(xml)
        #expect(elem.name == "root")
        #expect(elem.getChild("child") != nil)
    }

    @Test("UTF-8 BOM with parseAll")
    func testBOMParseAll() throws {
        let xml = "\u{FEFF}<!-- comment --><root/>"
        let nodes = try XMLElement.parseAll(xml)
        #expect(nodes.contains { $0.asElement?.name == "root" })
        #expect(nodes.contains { $0.asComment != nil })
    }

    // MARK: - PI trailing whitespace at parser level

    @Test("PI trailing whitespace is preserved through parse")
    func testPITrailingWhitespace() throws {
        let xml = "<root><?pi data ?></root>"
        let elem = try XMLElement.parse(xml)
        if case .processingInstruction(let target, let data) = elem.children.first {
            #expect(target == "pi")
            #expect(data == "data ")
        } else {
            Issue.record("Expected processing instruction child")
        }
    }

    // MARK: - Edge case inputs

    @Test("Empty string throws cannotParse")
    func testEmptyString() throws {
        #expect(throws: XMLParseError.self) {
            _ = try XMLElement.parse("")
        }
    }

    @Test("Whitespace-only string throws cannotParse")
    func testWhitespaceOnly() throws {
        #expect(throws: XMLParseError.self) {
            _ = try XMLElement.parse("   \n\t  ")
        }
    }

    @Test("parseAll with multiple root elements returns all")
    func testMultipleRoots() throws {
        let nodes = try XMLElement.parseAll("<a/><b/>")
        let elements = nodes.compactMap(\.asElement)
        #expect(elements.count == 2)
        #expect(elements[0].name == "a")
        #expect(elements[1].name == "b")
    }

    @Test("parse returns first root element when multiple are present")
    func testParseFirstRoot() throws {
        let elem = try XMLElement.parse("<first/><second/>")
        #expect(elem.name == "first")
    }
}
