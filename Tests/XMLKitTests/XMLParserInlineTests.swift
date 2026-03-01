import Foundation
import Testing

@testable import XMLKit

@Suite("XMLParser — Inline XML Tests")
struct XMLParserInlineTests {

    // MARK: - test_mut: Mutate child

    @Test("Mutate child element")
    func testMut() throws {
        let xml = """
            <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <names>
                <name first="bob" last="jones" />
                <name first="elizabeth" last="smith" />
            </names>
            """
        var element = try XMLElement.parse(xml)
        element.withMutableChild("name") { child in
            child.attributes["suffix"] = "mr"
        }
        #expect(element.getChild("name")?.attributes["suffix"] == "mr")
    }

    // MARK: - test_mal_01: Unclosed attribute quote

    @Test("Malformed XML — unclosed attribute quote")
    func testMal01() throws {
        let data = """
            <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <names>
                <name first="bob" last="jones />
                <name first="elizabeth" last="smith" />
            </names>
            """
        #expect(throws: XMLParseError.self) {
            _ = try XMLElement.parse(data)
        }
    }

    // MARK: - test_mal_02: Not XML at all

    @Test("Malformed XML — not XML at all")
    func testMal02() throws {
        let data = """
                    this is not even close
                    to XML
            """
        #expect(throws: XMLParseError.self) {
            _ = try XMLElement.parse(data)
        }
    }

    // MARK: - test_mal_03: Mismatched tags

    @Test("Malformed XML — mismatched closing tag")
    func testMal03() throws {
        let data = """
            <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <names>
                <name first="bob" last="jones"></badtag>
                <name first="elizabeth" last="smith" />
            </names>
            """
        #expect(throws: XMLParseError.self) {
            _ = try XMLElement.parse(data)
        }
    }

    // MARK: - test_new: Element construction

    @Test("Element construction")
    func testNew() throws {
        let element = XMLElement(name: "foo")
        #expect(element.name == "foo")
        #expect(element.attributes.isEmpty)
        #expect(element.children.isEmpty)
    }

    // MARK: - test_take: Take child and compare

    @Test("takeChild removes matching child")
    func testTake() throws {
        let xml1 = """
            <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <names>
                <name first="bob" last="jones"></name>
                <name first="elizabeth" last="smith" />
                <remove_me key="value">
                    <child />
                </remove_me>
            </names>
            """
        let xml2 = """
            <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <names>
                <name first="bob" last="jones"></name>
                <name first="elizabeth" last="smith" />
            </names>
            """

        var data1 = try XMLElement.parse(xml1)
        let data2 = try XMLElement.parse(xml2)

        if let removed = data1.takeChild("remove_me") {
            #expect(removed.children.count == 1)
        } else {
            Issue.record("takeChild failed")
        }

        #expect(data1 == data2)
    }

    // MARK: - test_text: getText() edge cases

    @Test("getText with no text returns nil")
    func testTextNone() throws {
        let data = """
            <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <elem><inner/></elem>
            """
        let elem = try XMLElement.parse(data)
        #expect(elem.getText() == nil)
    }

    @Test("getText with single text child")
    func testTextSingle() throws {
        let data = """
            <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <elem>hello world<inner/></elem>
            """
        let elem = try XMLElement.parse(data)
        #expect(elem.getText() == "hello world")
    }

    @Test("getText concatenates split text nodes")
    func testTextMultiple() throws {
        let data = """
            <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <elem>hello <inner/>world</elem>
            """
        let elem = try XMLElement.parse(data)
        #expect(elem.getText() == "hello world")
    }

    @Test("getText concatenates text and CDATA")
    func testTextWithCData() throws {
        let data = """
            <?xml version="1.0" encoding="utf-8" standalone="yes"?>
            <elem>hello <inner/><![CDATA[<world>]]></elem>
            """
        let elem = try XMLElement.parse(data)
        #expect(elem.getText() == "hello <world>")
    }

    // MARK: - ParserConfig tests

    @Test("parseAll with String and config filters comments")
    func testParseAllStringWithConfig() throws {
        let xml = "<!-- before --><root><child/></root><!-- after -->"
        let config = ParserConfig(ignoreComments: true)
        let nodes = try XMLElement.parseAll(xml, config: config)
        #expect(nodes.count == 1)
        #expect(nodes[0].asElement?.name == "root")
        for node in nodes {
            #expect(node.asComment == nil)
        }
    }

    @Test("ParserConfig ignoreComments removes comments")
    func testIgnoreComments() throws {
        let xml = "<root><!-- comment --><child/></root>"
        let config = ParserConfig(ignoreComments: true)
        let element = try XMLElement.parse(xml, config: config)
        for child in element.children {
            #expect(child.asComment == nil)
        }
    }

    @Test("ParserConfig ignoreProcessingInstructions removes PIs")
    func testIgnorePI() throws {
        let xml = "<root><?pi data?><child/></root>"
        let config = ParserConfig(ignoreProcessingInstructions: true)
        let element = try XMLElement.parse(xml, config: config)
        for child in element.children {
            #expect(child.asProcessingInstruction == nil)
        }
    }

    // MARK: - Entity decoding in parsed content

    @Test("Entity decoding in text content")
    func testEntityDecoding() throws {
        let xml = "<root>&lt;hello&gt; &amp; &quot;world&quot;</root>"
        let element = try XMLElement.parse(xml)
        #expect(element.getText() == "<hello> & \"world\"")
    }

    @Test("Numeric entity decoding")
    func testNumericEntity() throws {
        let xml = "<root>&#169; &#xA9;</root>"
        let element = try XMLElement.parse(xml)
        #expect(element.getText() == "\u{00A9} \u{00A9}")
    }

    // MARK: - Namespace resolution

    @Test("Default namespace resolution")
    func testDefaultNamespace() throws {
        let xml = "<root xmlns=\"urn:example\"><child/></root>"
        let element = try XMLElement.parse(xml)
        #expect(element.namespace == "urn:example")
        #expect(element.getChild("child")?.namespace == "urn:example")
    }

    @Test("Prefixed namespace resolution")
    func testPrefixedNamespace() throws {
        let xml = "<h:root xmlns:h=\"urn:html\"><h:child/></h:root>"
        let element = try XMLElement.parse(xml)
        #expect(element.namespace == "urn:html")
        #expect(element.prefix == "h")
        #expect(element.getChild("child")?.namespace == "urn:html")
    }

    // MARK: - Parse Data overload

    @Test("Parse from Data")
    func testParseData() throws {
        let xml = "<root><child/></root>"
        guard let data = xml.data(using: .utf8) else {
            Issue.record("Failed to encode test XML")
            return
        }
        let element = try XMLElement.parse(data)
        #expect(element.name == "root")
    }

    @Test("parseAll from Data")
    func testParseAllData() throws {
        let xml = "<root><child/></root>"
        guard let data = xml.data(using: .utf8) else {
            Issue.record("Failed to encode test XML")
            return
        }
        let nodes = try XMLElement.parseAll(data)
        #expect(nodes.count == 1)
    }

    @Test("XMLParseError description for malformedXML")
    func testParseErrorDescription() {
        let error = XMLParseError.malformedXML("Unexpected end of input", line: 3, column: 10)
        #expect(error.description == "Malformed XML at 3:10: Unexpected end of input")
    }

    @Test("XMLParseError description for cannotParse")
    func testCannotParseDescription() {
        let error = XMLParseError.cannotParse
        #expect(error.description == "Cannot parse XML document")
    }

    @Test("Tokenizer error reports correct line and column")
    func testErrorLineColumn() throws {
        // Missing '=' after attribute name on line 2, column 11 (the '>' where '=' was expected)
        let xml = "<root>\n<child bad></child>\n</root>"
        #expect {
            _ = try XMLElement.parse(xml)
        } throws: { error in
            guard let parseError = error as? XMLParseError,
                case .malformedXML(_, let line, let column) = parseError
            else { return false }
            return line == 2 && column == 11
        }
    }

    @Test("Unclosed attribute quote reports unterminated attribute value")
    func testErrorLineColumnUnclosedQuote() throws {
        let xml = "<root attr=\"unclosed>"
        #expect {
            _ = try XMLElement.parse(xml)
        } throws: { error in
            guard let parseError = error as? XMLParseError,
                case .malformedXML(let msg, _, _) = parseError
            else { return false }
            return msg.contains("Unterminated attribute value")
        }
    }

    @Test("Empty element name error on correct line")
    func testEmptyElementNameLine() throws {
        // Line 1: "<root>", line 2: "< >" has an empty element name
        let xml = "<root>\n< >\n</root>"
        #expect {
            _ = try XMLElement.parse(xml)
        } throws: { error in
            guard let parseError = error as? XMLParseError,
                case .malformedXML(let msg, let line, _) = parseError
            else { return false }
            return line == 2 && msg.contains("Empty element name")
        }
    }

    @Test("Mismatched closing tag reports correct position")
    func testMismatchedTagPosition() throws {
        // Line 1: "<root>", line 2: "</wrong>"
        let xml = "<root>\n</wrong>"
        #expect {
            _ = try XMLElement.parse(xml)
        } throws: { error in
            guard let parseError = error as? XMLParseError,
                case .malformedXML(let msg, let line, _) = parseError
            else { return false }
            return line == 2 && msg.contains("</root>") && msg.contains("</wrong>")
        }
    }

    @Test("Unclosed element reports opening tag position")
    func testUnclosedElementPosition() throws {
        // The opening tag <child> is on line 2 — error should point there
        let xml = "<root>\n<child>"
        #expect {
            _ = try XMLElement.parse(xml)
        } throws: { error in
            guard let parseError = error as? XMLParseError,
                case .malformedXML(let msg, let line, _) = parseError
            else { return false }
            return line == 2 && msg.contains("child")
        }
    }

}
