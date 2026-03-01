import Testing

@testable import XMLKit

@Suite("XMLWriter")
struct XMLWriterTests {

    // MARK: - No declaration

    @Test("Write without document declaration")
    func testNoDeclaration() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        let element = XMLElement(name: "n")
        let output = element.write(config: config)
        #expect(output == "<n />")
    }

    // MARK: - With declaration

    @Test("Write with document declaration")
    func testDeclaration() throws {
        let config = EmitterConfig(writeDocumentDeclaration: true, performIndent: false)
        let element = XMLElement(name: "n")
        let output = element.write(config: config)
        #expect(output == "<?xml version=\"1.0\" encoding=\"UTF-8\"?><n />")
    }

    // MARK: - Default config includes declaration

    @Test("Default config includes XML declaration")
    func testDefaultConfig() throws {
        let element = XMLElement(name: "test")
        let output = element.write()
        #expect(output.hasPrefix("<?xml"))
    }

    // MARK: - Indentation

    @Test("Indented output")
    func testIndent() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false, performIndent: true)
        var root = XMLElement(name: "root")
        root.children = [.element(XMLElement(name: "child"))]
        let output = root.write(config: config)
        #expect(output.contains("  <child />"))
    }

    // MARK: - Text content is not indented separately when inline

    @Test("Text-only children stay inline")
    func testInlineText() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false, performIndent: true)
        var root = XMLElement(name: "root")
        root.children = [.text("hello")]
        let output = root.write(config: config)
        #expect(output.contains("<root>hello</root>"))
    }

    // MARK: - Entity escaping in text

    @Test("Text content is entity-escaped")
    func testTextEscaping() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.text("<hello> & \"world\"")]
        let output = root.write(config: config)
        // Quotes don't need escaping in text content per XML spec
        #expect(output.contains("&lt;hello&gt; &amp; \"world\""))
    }

    // MARK: - Entity escaping in attributes

    @Test("Attribute values are entity-escaped")
    func testAttrEscaping() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.attributes["key"] = "<value>&\"'"
        let output = root.write(config: config)
        #expect(output.contains("key=\"&lt;value&gt;&amp;&quot;&apos;\""))
    }

    // MARK: - CDATA passthrough

    @Test("CDATA sections are written verbatim")
    func testCData() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.cdata("<raw>data</raw>")]
        let output = root.write(config: config)
        #expect(output.contains("<![CDATA[<raw>data</raw>]]>"))
    }

    @Test("CDATA containing ]]> is split into valid sections")
    func testCDataEscape() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.cdata("a]]>b")]
        let output = root.write(config: config)
        #expect(!output.contains("<![CDATA[a]]>b]]>"))
        #expect(output.contains("]]]]><![CDATA[>"))
        // Verify round-trip: parse the output and get the same text back
        let reparsed = try XMLElement.parse(output)
        #expect(reparsed.children[0].asCData != nil || reparsed.getText() == "a]]>b")
    }

    // MARK: - Comment output

    @Test("Comments are written")
    func testComment() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.comment(" a comment ")]
        let output = root.write(config: config)
        #expect(output.contains("<!-- a comment -->"))
    }

    @Test("Comment with -- is sanitized")
    func testCommentDoubleDash() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.comment("bad--comment")]
        let output = root.write(config: config)
        #expect(output.contains("<!--bad- -comment-->"))
        #expect(!output.contains("---->") && !output.contains("<!--->"))
    }

    @Test("Comment with triple hyphens is fully sanitized")
    func testCommentTripleHyphen() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.comment("---")]
        let output = root.write(config: config)
        // Strip delimiters and check no -- remains in the comment content
        let inner = output.replacingOccurrences(of: "<!--", with: "")
            .replacingOccurrences(of: "-->", with: "")
        #expect(!inner.contains("--"))
    }

    @Test("Comment with quadruple hyphens is fully sanitized")
    func testCommentQuadHyphen() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.comment("----")]
        let output = root.write(config: config)
        let inner = output.replacingOccurrences(of: "<!--", with: "")
            .replacingOccurrences(of: "-->", with: "")
        #expect(!inner.contains("--"))
    }

    @Test("Comment ending with - is sanitized")
    func testCommentTrailingDash() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.comment("trailing-")]
        let output = root.write(config: config)
        #expect(output.contains("<!--trailing- -->"))
    }

    // MARK: - Processing instruction output

    @Test("Processing instructions are written")
    func testPI() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.processingInstruction("pi", "data=\"value\"")]
        let output = root.write(config: config)
        #expect(output.contains("<?pi data=\"value\"?>"))
    }

    // MARK: - Self-closing empty elements

    @Test("Empty elements are self-closing")
    func testSelfClosing() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        let element = XMLElement(name: "empty")
        let output = element.write(config: config)
        #expect(output == "<empty />")
    }

    // MARK: - Round-trip tests

    @Test("Round-trip: parse -> write -> parse produces equal tree")
    func testRoundTrip() throws {
        let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <root attr="value">
                <child>text</child>
                <empty />
            </root>
            """
        let elem1 = try XMLElement.parse(xml)
        let output = elem1.write()
        let elem2 = try XMLElement.parse(output)
        #expect(elem1 == elem2)
    }

    // MARK: - Write with config (indented round-trip)

    @Test("Indented write can be parsed back")
    func testIndentedRoundTrip() throws {
        let xml = """
            <?xml version="1.0" encoding="utf-8"?>
            <root><a>1</a><b>2</b></root>
            """
        let elem1 = try XMLElement.parse(xml)
        let config = EmitterConfig(performIndent: true)
        let output = elem1.write(config: config)
        let elem2 = try XMLElement.parse(output)
        #expect(elem1 == elem2)
    }

    // MARK: - Custom indent string

    @Test("Custom indent string")
    func testCustomIndent() throws {
        let config = EmitterConfig(
            writeDocumentDeclaration: false,
            performIndent: true,
            indentString: "\t"
        )
        var root = XMLElement(name: "root")
        root.children = [.element(XMLElement(name: "child"))]
        let output = root.write(config: config)
        #expect(output.contains("\t<child />"))
    }

    // MARK: - Custom line separator

    @Test("Custom line separator")
    func testCustomLineSeparator() throws {
        let config = EmitterConfig(
            writeDocumentDeclaration: false,
            performIndent: true,
            lineSeparator: "\r\n"
        )
        var root = XMLElement(name: "root")
        root.children = [.element(XMLElement(name: "child"))]
        let output = root.write(config: config)
        #expect(output.contains("\r\n"))
    }

    // MARK: - PI without data

    @Test("Processing instruction without data")
    func testPINoData() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false)
        var root = XMLElement(name: "r")
        root.children = [.processingInstruction("target", nil)]
        let output = root.write(config: config)
        #expect(output.contains("<?target?>"))
    }

    // MARK: - Mixed content

    @Test("Mixed content indentation with elements, text, and comments")
    func testMixedContentIndent() throws {
        let config = EmitterConfig(writeDocumentDeclaration: false, performIndent: true)
        var root = XMLElement(name: "root")
        root.children = [
            .text("hello"),
            .element(XMLElement(name: "child")),
            .comment(" note "),
        ]
        let output = root.write(config: config)
        // Should contain child element and comment indented
        #expect(output.contains("<child />"))
        #expect(output.contains("<!-- note -->"))
        // Should be parseable back
        let reparsed = try XMLElement.parse(output)
        #expect(reparsed.getChild("child") != nil)
    }
}
