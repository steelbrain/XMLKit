import Testing

@testable import XMLKit

@Suite("XMLTokenizer — Validation & Edge Cases")
struct XMLTokenizerValidationTests {

    // MARK: - Malformed element names

    @Test("Empty element name throws")
    func emptyElementName() throws {
        let xml = "< >"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Element name starting with digit is rejected")
    func elementNameStartsWithDigit() throws {
        let xml = "<1bad/>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Element name starting with dash is rejected")
    func elementNameStartsWithDash() throws {
        let xml = "<-bad/>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Element name starting with dot is rejected")
    func elementNameStartsWithDot() throws {
        let xml = "<.bad/>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Element name with digits after start char is accepted")
    func elementNameWithDigits() throws {
        let xml = "<h1/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(let name, _, _, _, _) = tokens[0] {
            #expect(name == "h1")
        } else {
            Issue.record("Expected startElement token")
        }
    }

    // MARK: - Unterminated constructs

    @Test("Unterminated comment throws")
    func unterminatedComment() throws {
        let xml = "<!-- this comment never ends"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Unterminated CDATA throws")
    func unterminatedCData() throws {
        let xml = "<![CDATA[ this cdata never ends"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Unterminated DOCTYPE throws")
    func unterminatedDoctype() throws {
        let xml = "<!DOCTYPE foo"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    // MARK: - Entity errors

    @Test("Unterminated entity reference throws")
    func unterminatedEntity() throws {
        let xml = "<r>&amp without semicolon</r>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Unterminated entity in attribute throws")
    func unterminatedEntityInAttribute() throws {
        let xml = "<r attr=\"&amp\"/>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Unknown entity reference throws")
    func unknownEntity() throws {
        let xml = "<r>&foo;</r>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Invalid numeric character reference throws")
    func invalidNumericEntity() throws {
        let xml = "<r>&#xFFFFFFFF;</r>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Invalid decimal character reference throws")
    func invalidDecimalEntity() throws {
        let xml = "<r>&#99999999;</r>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Null character entity &#0; is rejected")
    func nullCharacterEntity() throws {
        let xml = "<r>&#0;</r>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Control character entity &#1; is rejected")
    func controlCharacterEntity() throws {
        let xml = "<r>&#1;</r>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Valid XML character entities are accepted")
    func validXMLCharEntities() throws {
        let xml = "<r>&#9;&#10;&#13;</r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .whitespace(let text) = tokens[1] {
            #expect(text.contains("\t"))
            #expect(text.contains("\n"))
        } else {
            Issue.record("Expected whitespace token, got \(tokens[1])")
        }
    }

    // MARK: - Attribute errors

    @Test("Literal < in attribute value throws")
    func lessThanInAttribute() throws {
        let xml = "<r attr=\"a<b\"/>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Duplicate attributes throw")
    func duplicateAttributes() throws {
        let xml = "<r a=\"1\" a=\"2\"/>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Duplicate attributes after prefix stripping throw")
    func duplicateAttributesPrefixed() throws {
        let xml = "<r x:a=\"1\" y:a=\"2\"/>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Attribute value whitespace is normalized")
    func attributeWhitespaceNormalization() throws {
        let xml = "<r attr=\"a\tb\nc\r\nd\re\"/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .startElement(_, _, let attrs, _, _) = tokens[0] {
            #expect(attrs["attr"] == "a b c d e")
        } else {
            Issue.record("Expected startElement")
        }
    }

    // MARK: - Comment validation

    @Test("Comment containing -- is rejected")
    func commentWithDoubleDash() throws {
        let xml = "<r><!-- bad--comment --></r>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Comment without -- is accepted")
    func commentWithoutDoubleDash() throws {
        let xml = "<r><!-- good-comment --></r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        let commentToken = tokens.first { token in
            if case .comment = token { return true }
            return false
        }
        if case .comment(let content) = commentToken {
            #expect(content == " good-comment ")
        } else {
            Issue.record("Expected comment token")
        }
    }

    // MARK: - Text content validation

    @Test("Text content containing ]]> is rejected")
    func cdataEndInText() throws {
        let xml = "<r>some]]>text</r>"
        var tokenizer = XMLTokenizer(xml)
        #expect(throws: XMLParseError.self) {
            _ = try tokenizer.tokenize()
        }
    }

    @Test("Text content with ] alone is accepted")
    func singleBracketInText() throws {
        let xml = "<r>some]text</r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .text(let text) = tokens[1] {
            #expect(text == "some]text")
        } else {
            Issue.record("Expected text token")
        }
    }

    @Test("Text content with ]] alone is accepted")
    func doubleBracketInText() throws {
        let xml = "<r>some]]text</r>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        if case .text(let text) = tokens[1] {
            #expect(text == "some]]text")
        } else {
            Issue.record("Expected text token")
        }
    }

    // MARK: - DOCTYPE edge cases

    @Test("DOCTYPE with > inside quoted string is parsed correctly")
    func doctypeQuotedAngleBracket() throws {
        let xml = "<!DOCTYPE html SYSTEM \"te>st.dtd\"><r/>"
        var tokenizer = XMLTokenizer(xml)
        let tokens = try tokenizer.tokenize()
        #expect(tokens[0] == .doctype)
        if case .startElement(let name, _, _, _, _) = tokens[1] {
            #expect(name == "r")
        } else {
            Issue.record("Expected startElement after DOCTYPE")
        }
    }
}
