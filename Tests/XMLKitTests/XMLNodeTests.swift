import Testing

@testable import XMLKit

@Suite("XMLNode")
struct XMLNodeTests {

    @Test("asElement returns element")
    func asElement() {
        let elem = XMLElement(name: "test")
        let node = XMLNode.element(elem)
        #expect(node.asElement != nil)
        #expect(node.asElement?.name == "test")
    }

    @Test("asElement returns nil for non-element")
    func asElementNil() {
        let node = XMLNode.text("hello")
        #expect(node.asElement == nil)
    }

    @Test("asComment returns comment text")
    func asComment() {
        let node = XMLNode.comment("a comment")
        #expect(node.asComment == "a comment")
    }

    @Test("asComment returns nil for non-comment")
    func asCommentNil() {
        let node = XMLNode.text("hello")
        #expect(node.asComment == nil)
    }

    @Test("asCData returns CDATA text")
    func asCData() {
        let node = XMLNode.cdata("<data>")
        #expect(node.asCData == "<data>")
    }

    @Test("asCData returns nil for non-CDATA")
    func asCDataNil() {
        let node = XMLNode.text("hello")
        #expect(node.asCData == nil)
    }

    @Test("asText returns text string")
    func asText() {
        let node = XMLNode.text("hello world")
        #expect(node.asText == "hello world")
    }

    @Test("asText returns nil for non-text")
    func asTextNil() {
        let node = XMLNode.comment("x")
        #expect(node.asText == nil)
    }

    @Test("asProcessingInstruction returns target and data")
    func asProcessingInstruction() {
        let node = XMLNode.processingInstruction("target", "data here")
        let pi = node.asProcessingInstruction
        #expect(pi?.target == "target")
        #expect(pi?.data == "data here")
    }

    @Test("asProcessingInstruction with nil data")
    func asProcessingInstructionNilData() {
        let node = XMLNode.processingInstruction("target", nil)
        let pi = node.asProcessingInstruction
        #expect(pi?.target == "target")
        #expect(pi?.data == nil)
    }

    @Test("asProcessingInstruction returns nil for non-PI")
    func asProcessingInstructionNil() {
        let node = XMLNode.text("hello")
        #expect(node.asProcessingInstruction == nil)
    }

    @Test("withElement mutates element in place")
    func withElement() {
        var node = XMLNode.element(XMLElement(name: "orig"))
        node.withElement { elem in
            elem.name = "modified"
            elem.attributes["key"] = "value"
        }
        #expect(node.asElement?.name == "modified")
        #expect(node.asElement?.attributes["key"] == "value")
    }

    @Test("withElement returns nil for non-element")
    func withElementNonElement() {
        var node = XMLNode.text("hello")
        let result: Void? = node.withElement { _ in }
        #expect(result == nil)
    }

    @Test("XMLNode equality")
    func equality() {
        let node1 = XMLNode.text("hello")
        let node2 = XMLNode.text("hello")
        let node3 = XMLNode.text("world")
        #expect(node1 == node2)
        #expect(node1 != node3)
    }

    @Test("XMLNode can be used in a Set")
    func hashableSet() {
        let elem = XMLElement(name: "item")
        let nodes: Set<XMLNode> = [
            .text("hello"),
            .text("hello"),
            .comment("c"),
            .cdata("data"),
            .element(elem),
            .element(elem),
        ]
        #expect(nodes.count == 4)
        #expect(nodes.contains(.text("hello")))
        #expect(nodes.contains(.comment("c")))
        #expect(nodes.contains(.element(elem)))
    }

    @Test("XMLNode can be used as Dictionary key")
    func hashableDictionaryKey() {
        var dict: [XMLNode: Int] = [:]
        dict[.text("a")] = 1
        dict[.text("b")] = 2
        dict[.text("a")] = 3
        #expect(dict.count == 2)
        #expect(dict[.text("a")] == 3)
    }

    @Test("description for text node")
    func descriptionText() {
        let node = XMLNode.text("hello")
        #expect(node.description == "hello")
    }

    @Test("description for text node escapes XML entities")
    func descriptionTextEscapes() {
        let node = XMLNode.text("a < b & c > d")
        #expect(node.description == "a &lt; b &amp; c &gt; d")
    }

    @Test("description for comment node")
    func descriptionComment() {
        let node = XMLNode.comment(" a comment ")
        #expect(node.description == "<!-- a comment -->")
    }

    @Test("description for CDATA node")
    func descriptionCData() {
        let node = XMLNode.cdata("raw <data>")
        #expect(node.description == "<![CDATA[raw <data>]]>")
    }

    @Test("description for processing instruction")
    func descriptionPI() {
        let node = XMLNode.processingInstruction("target", "data here")
        #expect(node.description == "<?target data here?>")
    }

    @Test("description for processing instruction without data")
    func descriptionPINoData() {
        let node = XMLNode.processingInstruction("target", nil)
        #expect(node.description == "<?target?>")
    }

    @Test("description for CDATA node containing ]]> is escaped")
    func descriptionCDataEscape() {
        let node = XMLNode.cdata("a]]>b")
        #expect(node.description == "<![CDATA[a]]]]><![CDATA[><![CDATA[b]]>")
    }

    @Test("description for comment node sanitizes --")
    func descriptionCommentSanitize() {
        let node = XMLNode.comment("bad--comment")
        #expect(node.description == "<!--bad- -comment-->")
    }

    @Test("description for comment node sanitizes trailing -")
    func descriptionCommentTrailingDash() {
        let node = XMLNode.comment("ends-")
        #expect(node.description == "<!--ends- -->")
    }

    @Test("description for element node delegates to XMLElement")
    func descriptionElement() {
        var elem = XMLElement(name: "root")
        elem.children = [.text("hello")]
        let node = XMLNode.element(elem)
        #expect(node.description == "<root>hello</root>")
    }
}
