import Foundation
import Testing

@testable import XMLKit

/// Helper to load a fixture file from the test bundle.
func loadFixture(_ name: String) throws -> String {
    guard let url = Bundle.module.url(forResource: name, withExtension: "xml", subdirectory: "Fixtures")
    else {
        throw XMLParseError.cannotParse
    }
    return try String(contentsOf: url, encoding: .utf8)
}

@Suite("XMLParser — Fixture Tests")
struct XMLParserFixtureTests {

    // MARK: - test_01: Parse 01.xml, check structure, round-trip

    @Test("Parse 01.xml — project with libraries and entities")
    func test01() throws {
        let xml = try loadFixture("01")
        let element = try XMLElement.parse(xml)

        #expect(element.name == "project")

        let libs = element.getChild("libraries")
        #expect(libs != nil)
        #expect(libs?.name == "libraries")

        #expect(element.getChild("doesnotexist") == nil)

        // Round-trip
        let output = element.write()
        let reparsed = try XMLElement.parse(output)
        #expect(element == reparsed)
    }

    // MARK: - test_02: Parse 02.xml (multiple namespace prefixes)

    @Test("Parse 02.xml — multiple namespace prefixes")
    func test02() throws {
        let xml = try loadFixture("02")
        let element = try XMLElement.parse(xml)
        #expect(element.name == "data")
        #expect(element.prefix == "p")
        #expect(element.namespace == "urn:example:namespace")

        // Verify child element with prefix
        let datum = element.getChild("datum")
        #expect(datum != nil)
        #expect(datum?.prefix == "p")
        #expect(datum?.namespace == "urn:example:namespace")
        #expect(datum?.attributes["id"] == "34")

        // Verify children under different namespace prefixes
        let pName = datum?.getChild("name", namespace: "urn:example:namespace")
        #expect(pName != nil)
        #expect(pName?.getText() == "Name")

        let dName = datum?.getChild("name", namespace: "urn:example:double")
        #expect(dName != nil)
        #expect(dName?.getText() == "Another name")

        let hHeader = datum?.getChild("header", namespace: "urn:example:header")
        #expect(hHeader != nil)
        #expect(hHeader?.prefix == "h")
        #expect(hHeader?.attributes["name"] == "Header-1")
    }

    // MARK: - test_03: Parse 03.xml (comments, CDATA, special chars)

    @Test("Parse 03.xml — comments, CDATA, special attribute chars")
    func test03() throws {
        let xml = try loadFixture("03")
        let element = try XMLElement.parse(xml)
        #expect(element.name == "data")
        #expect(element.prefix == "p")

        // Attribute with > in value
        #expect(element.attributes["z"] == ">")

        // Comment child exists
        let hasComment = element.children.contains { $0.asComment != nil }
        #expect(hasComment)

        // CDATA children exist
        let cdataNodes = element.children.filter { $0.asCData != nil }
        #expect(!cdataNodes.isEmpty)

        // Named child elements are present
        #expect(element.getChild("a")?.getText() == "test")
        #expect(element.getChild("c") != nil)
    }

    // MARK: - test_04: Parse 04.xml (DOCTYPE, comment, PI)

    @Test("Parse 04.xml — DOCTYPE, leading comment, processing instruction")
    func test04() throws {
        let xml = try loadFixture("04")
        let element = try XMLElement.parse(xml)
        #expect(element.name == "data")

        // First child should be a PI
        let pi = element.children[0].asProcessingInstruction
        #expect(pi != nil)
        #expect(pi?.target == "pi")
        #expect(pi?.data == "foo=\"blah\"")
    }

    // MARK: - test_parse_all: Parse all nodes from 04.xml

    @Test("parseAll from 04.xml returns comment + element + comment")
    func testParseAll() throws {
        let xml = try loadFixture("04")
        let nodes = try XMLElement.parseAll(xml)

        #expect(nodes.count == 3)
        #expect(nodes[0].asComment != nil)
    }

    // MARK: - test_no_root_node: 05.xml is a CDATA-only error case

    @Test("05.xml — CDATA without root element is an error for parse()")
    func testNoRootNode() throws {
        let xml = try loadFixture("05")
        #expect(throws: XMLParseError.self) {
            _ = try XMLElement.parse(xml)
        }
    }

    @Test("05.xml — CDATA without root element is an error for parseAll()")
    func testNoRootNodeParseAll() throws {
        let xml = try loadFixture("05")
        #expect(throws: XMLParseError.self) {
            _ = try XMLElement.parseAll(xml)
        }
    }

    // MARK: - test_rw: Round-trip rw.xml

    @Test("Round-trip rw.xml")
    func testRW() throws {
        let xml = try loadFixture("rw")
        let element = try XMLElement.parse(xml)

        let output = element.write()
        let reparsed = try XMLElement.parse(output)
        #expect(element == reparsed)
    }

    // MARK: - test_ns_rw: Namespace round-trip for ns1.xml and ns2.xml

    @Test("Namespace round-trip ns1.xml")
    func testNSRW1() throws {
        let xml = try loadFixture("ns1")
        let element = try XMLElement.parse(xml)

        let output = element.write()
        let reparsed = try XMLElement.parse(output)
        #expect(element == reparsed)
    }

    @Test("Namespace round-trip ns2.xml")
    func testNSRW2() throws {
        let xml = try loadFixture("ns2")
        let element = try XMLElement.parse(xml)

        let output = element.write()
        let reparsed = try XMLElement.parse(output)
        #expect(element == reparsed)
    }

    // MARK: - test_ns: Namespace child lookup

    @Test("Namespace child lookup in ns1.xml")
    func testNS() throws {
        let xml = try loadFixture("ns1")
        let element = try XMLElement.parse(xml)

        let htbl = element.getChild("table", namespace: "http://www.w3.org/TR/html4/")
        let ftbl = element.getChild("table", namespace: "https://www.w3schools.com/furniture")

        #expect(htbl != nil)
        #expect(ftbl != nil)
        #expect(htbl != ftbl)
    }
}
