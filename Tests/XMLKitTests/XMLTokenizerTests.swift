import Testing

@testable import XMLKit

@Suite("XMLTokenizer")
struct XMLTokenizerTests {

    // MARK: - Entity decoding

    @Test("Decodes named entities in text")
    func namedEntities() throws {
        let xml = "<root>&lt;&gt;&amp;&quot;&apos;</root>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        let textToken = tokens.first { token in
            if case .text = token { return true }
            return false
        }
        if case .text(let text) = textToken {
            #expect(text == "<>&\"'")
        } else {
            Issue.record("Expected text token")
        }
    }

    @Test("Decodes numeric character references")
    func numericEntities() throws {
        let xml = "<r>&#169; &#xA9;</r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        let textToken = tokens.first { token in
            if case .text = token { return true }
            return false
        }
        if case .text(let text) = textToken {
            #expect(text == "\u{00A9} \u{00A9}")
        } else {
            Issue.record("Expected text token")
        }
    }

    @Test("Decodes entities in attribute values")
    func attributeEntities() throws {
        let xml = "<r attr=\"&lt;value&gt;\"/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(_, _, let attrs, _, _) = tokens[0] {
            #expect(attrs["attr"] == "<value>")
        } else {
            Issue.record("Expected startElement")
        }
    }

    // MARK: - CDATA

    @Test("Tokenizes CDATA sections")
    func cdata() throws {
        let xml = "<r><![CDATA[<not>xml&]]></r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        let cdataToken = tokens.first { token in
            if case .cdata = token { return true }
            return false
        }
        if case .cdata(let content) = cdataToken {
            #expect(content == "<not>xml&")
        } else {
            Issue.record("Expected cdata token")
        }
    }

    @Test("CDATA with ]] inside")
    func cdataWithBrackets() throws {
        let xml = "<r><![CDATA[zzzz]]]]><![CDATA[>]]></r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        let cdataTokens = tokens.compactMap { token -> String? in
            if case .cdata(let content) = token { return content }
            return nil
        }
        #expect(cdataTokens == ["zzzz]]", ">"])
    }

    // MARK: - Comments

    @Test("Tokenizes comments")
    func comments() throws {
        let xml = "<r><!-- a comment --></r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        let commentToken = tokens.first { token in
            if case .comment = token { return true }
            return false
        }
        if case .comment(let content) = commentToken {
            #expect(content == " a comment ")
        } else {
            Issue.record("Expected comment token")
        }
    }

    // MARK: - Processing instructions

    @Test("Tokenizes processing instructions")
    func processingInstruction() throws {
        let xml = "<r><?pi data here?></r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        let piToken = tokens.first { token in
            if case .processingInstruction = token { return true }
            return false
        }
        if case .processingInstruction(let target, let data) = piToken {
            #expect(target == "pi")
            #expect(data == "data here")
        } else {
            Issue.record("Expected PI token")
        }
    }

    // MARK: - Self-closing tags

    @Test("Self-closing element")
    func selfClosing() throws {
        let xml = "<item />"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(let name, _, _, _, let sc) = tokens[0] {
            #expect(name == "item")
            #expect(sc == true)
        } else {
            Issue.record("Expected self-closing startElement")
        }
    }

    // MARK: - Namespace declarations

    @Test("Extracts namespace declarations from attributes")
    func namespaceDeclarations() throws {
        let xml = "<root xmlns=\"urn:default\" xmlns:h=\"urn:html\"></root>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(_, _, let attrs, let nsDecls, _) = tokens[0] {
            #expect(nsDecls[""] == "urn:default")
            #expect(nsDecls["h"] == "urn:html")
            #expect(attrs.isEmpty)
        } else {
            Issue.record("Expected startElement")
        }
    }

    // MARK: - Prefixed elements

    @Test("Splits qualified name into prefix and local name")
    func prefixedElement() throws {
        let xml = "<h:table></h:table>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(let name, let prefix, _, _, _) = tokens[0] {
            #expect(name == "table")
            #expect(prefix == "h")
        } else {
            Issue.record("Expected startElement")
        }
    }

    // MARK: - DOCTYPE

    @Test("Tokenizes DOCTYPE declaration")
    func doctype() throws {
        let xml = "<!DOCTYPE html SYSTEM \"test.dtd\"><r/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        #expect(tokens[0] == .doctype)
    }

    // MARK: - Whitespace

    @Test("Whitespace-only text becomes whitespace token")
    func whitespace() throws {
        let xml = "<r>  \n  </r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        let ws = tokens.first { token in
            if case .whitespace = token { return true }
            return false
        }
        #expect(ws != nil)
    }

    // MARK: - Attribute quoting

    @Test("Single-quoted attribute values are parsed correctly")
    func singleQuotedAttributes() throws {
        let xml = "<r attr='hello' other='world'/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(_, _, let attrs, _, _) = tokens[0] {
            #expect(attrs["attr"] == "hello")
            #expect(attrs["other"] == "world")
        } else {
            Issue.record("Expected startElement")
        }
    }

    @Test("Single-quoted attribute with entities")
    func singleQuotedAttributeEntities() throws {
        let xml = "<r attr='a&amp;b'/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(_, _, let attrs, _, _) = tokens[0] {
            #expect(attrs["attr"] == "a&b")
        } else {
            Issue.record("Expected startElement")
        }
    }

    @Test("Empty attribute value is parsed as empty string")
    func emptyAttributeValue() throws {
        let xml = "<r attr=\"\"/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(_, _, let attrs, _, _) = tokens[0] {
            #expect(attrs["attr"] == "")
        } else {
            Issue.record("Expected startElement")
        }
    }

    @Test("Empty single-quoted attribute value")
    func emptySingleQuotedAttributeValue() throws {
        let xml = "<r attr=''/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(_, _, let attrs, _, _) = tokens[0] {
            #expect(attrs["attr"] == "")
        } else {
            Issue.record("Expected startElement")
        }
    }

    // MARK: - Line ending normalization

    @Test("CR+LF is normalized to LF in text content")
    func lineEndingCRLF() throws {
        let xml = "<r>hello\r\nworld</r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .text(let text) = tokens[1] {
            #expect(text == "hello\nworld")
            #expect(!text.contains("\r"))
        } else {
            Issue.record("Expected text token")
        }
    }

    @Test("Standalone CR is normalized to LF in text content")
    func lineEndingCR() throws {
        let xml = "<r>hello\rworld</r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .text(let text) = tokens[1] {
            #expect(text == "hello\nworld")
            #expect(!text.contains("\r"))
        } else {
            Issue.record("Expected text token")
        }
    }

    // MARK: - BOM handling

    @Test("UTF-8 BOM is stripped from input")
    func bomStripped() throws {
        let xml = "\u{FEFF}<r/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(let name, _, _, _, _) = tokens[0] {
            #expect(name == "r")
        } else {
            Issue.record("Expected startElement, got \(tokens[0])")
        }
    }

    @Test("UTF-8 BOM before XML declaration is stripped")
    func bomBeforeDeclaration() throws {
        let xml = "\u{FEFF}<?xml version=\"1.0\"?><r/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .processingInstruction(let target, _) = tokens[0] {
            #expect(target == "xml")
        } else {
            Issue.record("Expected PI token, got \(tokens[0])")
        }
    }

    // MARK: - PI trailing whitespace

    @Test("PI data with trailing whitespace is preserved")
    func piTrailingWhitespace() throws {
        let xml = "<r><?pi data ?></r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        let piToken = tokens.first { token in
            if case .processingInstruction = token { return true }
            return false
        }
        if case .processingInstruction(let target, let data) = piToken {
            #expect(target == "pi")
            #expect(data == "data ")
        } else {
            Issue.record("Expected PI token")
        }
    }
}
