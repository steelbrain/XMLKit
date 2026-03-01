import Testing

@testable import XMLKit

@Suite("XMLElement")
struct XMLElementTests {

    @Test("Element init sets name and empty fields")
    func elementNew() {
        let element = XMLElement(name: "foo")
        #expect(element.name == "foo")
        #expect(element.prefix == nil)
        #expect(element.namespace == nil)
        #expect(element.namespaces == nil)
        #expect(element.attributes.isEmpty)
        #expect(element.children.isEmpty)
    }

    @Test("getChild finds matching child")
    func getChild() {
        var parent = XMLElement(name: "root")
        var child1 = XMLElement(name: "a")
        child1.attributes["id"] = "1"
        var child2 = XMLElement(name: "b")
        child2.attributes["id"] = "2"
        parent.children = [.element(child1), .element(child2)]

        let found = parent.getChild("b")
        #expect(found != nil)
        #expect(found?.name == "b")
        #expect(found?.attributes["id"] == "2")
    }

    @Test("getChild returns nil when not found")
    func getChildNotFound() {
        let parent = XMLElement(name: "root")
        #expect(parent.getChild("missing") == nil)
    }

    @Test("getChild with name and namespace")
    func getChildWithNamespace() {
        var parent = XMLElement(name: "root")
        var child1 = XMLElement(name: "table")
        child1.namespace = "http://html"
        var child2 = XMLElement(name: "table")
        child2.namespace = "http://furniture"
        parent.children = [.element(child1), .element(child2)]

        let found = parent.getChild("table", namespace: "http://furniture")
        #expect(found?.namespace == "http://furniture")
    }

    @Test("indexOfChild returns correct index")
    func indexOfChild() {
        var parent = XMLElement(name: "root")
        parent.children = [
            .element(XMLElement(name: "a")),
            .text("text"),
            .element(XMLElement(name: "b")),
        ]

        #expect(parent.indexOfChild("a") == 0)
        #expect(parent.indexOfChild("b") == 2)
        #expect(parent.indexOfChild("c") == nil)
    }

    @Test("indexOfChild with namespace returns correct index")
    func indexOfChildWithNamespace() {
        var parent = XMLElement(name: "root")
        var html = XMLElement(name: "table")
        html.namespace = "http://html"
        var furniture = XMLElement(name: "table")
        furniture.namespace = "http://furniture"
        parent.children = [
            .element(html),
            .text("gap"),
            .element(furniture),
        ]

        #expect(parent.indexOfChild("table", namespace: "http://html") == 0)
        #expect(parent.indexOfChild("table", namespace: "http://furniture") == 2)
        #expect(parent.indexOfChild("table", namespace: "http://other") == nil)
    }

    @Test("takeChild removes and returns matching child")
    func takeChild() {
        var parent = XMLElement(name: "root")
        parent.children = [
            .element(XMLElement(name: "a")),
            .element(XMLElement(name: "b")),
            .element(XMLElement(name: "c")),
        ]

        let taken = parent.takeChild("b")
        #expect(taken?.name == "b")
        #expect(parent.children.count == 2)
        #expect(parent.getChild("b") == nil)
    }

    @Test("takeChild with namespace removes correct child")
    func takeChildWithNamespace() {
        var parent = XMLElement(name: "root")
        var html = XMLElement(name: "table")
        html.namespace = "http://html"
        var furniture = XMLElement(name: "table")
        furniture.namespace = "http://furniture"
        parent.children = [.element(html), .element(furniture)]

        let taken = parent.takeChild("table", namespace: "http://furniture")
        #expect(taken?.name == "table")
        #expect(taken?.namespace == "http://furniture")
        #expect(parent.children.count == 1)
        #expect(parent.getChild("table", namespace: "http://html") != nil)
        #expect(parent.getChild("table", namespace: "http://furniture") == nil)
    }

    @Test("takeChild returns nil when not found")
    func takeChildNotFound() {
        var parent = XMLElement(name: "root")
        parent.children = [.element(XMLElement(name: "a"))]

        let taken = parent.takeChild("missing")
        #expect(taken == nil)
        #expect(parent.children.count == 1)
    }

    @Test("withMutableChild mutates matching child in place")
    func withMutableChild() {
        var parent = XMLElement(name: "root")
        var child = XMLElement(name: "name")
        child.attributes["first"] = "bob"
        parent.children = [.element(child)]

        parent.withMutableChild("name") { elem in
            elem.attributes["suffix"] = "mr"
        }

        #expect(parent.getChild("name")?.attributes["suffix"] == "mr")
        #expect(parent.getChild("name")?.attributes["first"] == "bob")
    }

    @Test("withMutableChild returns nil when not found")
    func withMutableChildNotFound() {
        var parent = XMLElement(name: "root")
        parent.children = [.element(XMLElement(name: "a"))]

        let result: Void? = parent.withMutableChild("missing") { _ in }
        #expect(result == nil)
    }

    @Test("withMutableChild with name and namespace")
    func withMutableChildNamespace() {
        var parent = XMLElement(name: "root")
        var child = XMLElement(name: "table")
        child.namespace = "http://html"
        parent.children = [.element(child)]

        parent.withMutableChild("table", namespace: "http://html") { elem in
            elem.attributes["border"] = "1"
        }

        #expect(parent.getChild("table", namespace: "http://html")?.attributes["border"] == "1")
    }

    @Test("getText returns nil when no text children")
    func getTextNone() {
        var parent = XMLElement(name: "elem")
        parent.children = [.element(XMLElement(name: "inner"))]
        #expect(parent.getText() == nil)
    }

    @Test("getText returns nil on childless element")
    func getTextChildless() {
        let elem = XMLElement(name: "empty")
        #expect(elem.getText() == nil)
    }

    @Test("getText returns single text child")
    func getTextSingle() {
        var parent = XMLElement(name: "elem")
        parent.children = [.text("hello world")]
        #expect(parent.getText() == "hello world")
    }

    @Test("getText concatenates multiple text nodes")
    func getTextMultiple() {
        var parent = XMLElement(name: "elem")
        parent.children = [
            .text("hello "),
            .element(XMLElement(name: "inner")),
            .text("world"),
        ]
        #expect(parent.getText() == "hello world")
    }

    @Test("getText includes CDATA content")
    func getTextWithCData() {
        var parent = XMLElement(name: "elem")
        parent.children = [
            .text("hello "),
            .element(XMLElement(name: "inner")),
            .cdata("<world>"),
        ]
        #expect(parent.getText() == "hello <world>")
    }

    @Test("matches checks element name")
    func matchesByName() {
        let elem = XMLElement(name: "test")
        #expect(elem.matches("test"))
        #expect(!elem.matches("other"))
    }

    @Test("matches checks name and namespace")
    func matchesByNameAndNamespace() {
        var elem = XMLElement(name: "table")
        elem.namespace = "http://html"
        #expect(elem.matches("table", namespace: "http://html"))
        #expect(!elem.matches("table", namespace: "http://other"))
    }

    @Test("XMLElement equality")
    func equality() {
        var elem1 = XMLElement(name: "test")
        elem1.attributes["key"] = "value"
        var elem2 = XMLElement(name: "test")
        elem2.attributes["key"] = "value"
        #expect(elem1 == elem2)

        var elem3 = XMLElement(name: "test")
        elem3.attributes["key"] = "different"
        #expect(elem1 != elem3)
    }

    @Test("XMLElement can be used in a Set")
    func hashableSet() {
        var elem1 = XMLElement(name: "a")
        elem1.attributes["id"] = "1"
        var elem2 = XMLElement(name: "a")
        elem2.attributes["id"] = "1"
        let elem3 = XMLElement(name: "b")

        let set: Set<XMLElement> = [elem1, elem2, elem3]
        #expect(set.count == 2)
    }

    @Test("XMLElement can be used as Dictionary key")
    func hashableDictionaryKey() {
        let elem1 = XMLElement(name: "key1")
        let elem2 = XMLElement(name: "key2")
        var dict: [XMLElement: String] = [:]
        dict[elem1] = "val1"
        dict[elem2] = "val2"
        #expect(dict[elem1] == "val1")
        #expect(dict[elem2] == "val2")
    }

    @Test("description returns compact XML without declaration")
    func description() {
        var elem = XMLElement(name: "root")
        elem.children = [.text("hello")]
        #expect(elem.description == "<root>hello</root>")
    }

    @Test("description for empty element")
    func descriptionEmpty() {
        let elem = XMLElement(name: "empty")
        #expect(elem.description == "<empty />")
    }

    @Test("description for element with attributes")
    func descriptionWithAttributes() {
        var elem = XMLElement(name: "item")
        elem.attributes["id"] = "1"
        elem.children = [.text("value")]
        #expect(elem.description == "<item id=\"1\">value</item>")
    }

    @Test("description for prefixed element with namespace")
    func descriptionPrefixed() {
        var elem = XMLElement(name: "Envelope")
        elem.prefix = "s"
        elem.namespaces = XMLNamespaceMap(["s": "http://schemas.xmlsoap.org/soap/envelope/"])
        elem.children = [.element(XMLElement(name: "Body"))]
        let desc = elem.description
        #expect(desc.hasPrefix("<s:Envelope"))
        #expect(desc.contains("xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\""))
        #expect(desc.hasSuffix("</s:Envelope>"))
    }

    @Test("subscript returns matching child element")
    func subscriptByName() {
        var parent = XMLElement(name: "root")
        var child = XMLElement(name: "item")
        child.attributes["id"] = "1"
        parent.children = [.element(child)]

        #expect(parent["item"]?.attributes["id"] == "1")
    }

    @Test("subscript returns nil for missing child")
    func subscriptMissing() {
        let parent = XMLElement(name: "root")
        #expect(parent["missing"] == nil)
    }

    @Test("subscript with namespace")
    func subscriptWithNamespace() {
        var parent = XMLElement(name: "root")
        var child1 = XMLElement(name: "table")
        child1.namespace = "http://html"
        var child2 = XMLElement(name: "table")
        child2.namespace = "http://furniture"
        parent.children = [.element(child1), .element(child2)]

        #expect(parent["table", namespace: "http://furniture"]?.namespace == "http://furniture")
        #expect(parent["table", namespace: "http://other"] == nil)
    }

    @Test("elementChildren returns only element children")
    func elementChildren() {
        var parent = XMLElement(name: "root")
        parent.children = [
            .text("text"),
            .element(XMLElement(name: "a")),
            .comment("comment"),
            .element(XMLElement(name: "b")),
            .cdata("data"),
        ]
        let elements = parent.elementChildren
        #expect(elements.count == 2)
        #expect(elements[0].name == "a")
        #expect(elements[1].name == "b")
    }

    @Test("elementChildren on empty children")
    func elementChildrenEmpty() {
        let parent = XMLElement(name: "root")
        #expect(parent.elementChildren.isEmpty)
    }

    @Test("elementChildren with no element children")
    func elementChildrenNoElements() {
        var parent = XMLElement(name: "root")
        parent.children = [.text("hello"), .comment("c")]
        #expect(parent.elementChildren.isEmpty)
    }
}

@Suite("XMLElement — Builder DSL")
struct XMLElementBuilderTests {

    @Test("build creates simple element tree")
    func buildSimple() {
        let root = XMLElement.build("root") {
            XMLElement.build("child")
        }
        #expect(root.name == "root")
        #expect(root.children.count == 1)
        #expect(root.children[0].asElement?.name == "child")
    }

    @Test("build with text content")
    func buildWithText() {
        let elem = XMLElement.build("greeting") {
            "Hello, world!"
        }
        #expect(elem.getText() == "Hello, world!")
    }

    @Test("build with attributes")
    func buildWithAttributes() {
        let elem = XMLElement.build("item", attributes: ["id": "1", "class": "active"]) {
            "content"
        }
        #expect(elem.attributes["id"] == "1")
        #expect(elem.attributes["class"] == "active")
        #expect(elem.getText() == "content")
    }

    @Test("build with nested elements")
    func buildNested() {
        let root = XMLElement.build("root") {
            XMLElement.build("parent") {
                XMLElement.build("child", attributes: ["id": "1"]) {
                    "text"
                }
            }
        }
        let parent = root["parent"]
        #expect(parent != nil)
        let child = parent?["child"]
        #expect(child?.attributes["id"] == "1")
        #expect(child?.getText() == "text")
    }

    @Test("build leaf element without content closure")
    func buildLeaf() {
        let elem = XMLElement.build("empty")
        #expect(elem.name == "empty")
        #expect(elem.children.isEmpty)
    }

    @Test("build with optional content")
    func buildWithOptional() {
        let includeChild = true
        let root = XMLElement.build("root") {
            if includeChild {
                XMLElement.build("present")
            }
        }
        #expect(root.children.count == 1)
        #expect(root.children[0].asElement?.name == "present")

        let root2 = XMLElement.build("root") {
            if !includeChild {
                XMLElement.build("absent")
            }
        }
        #expect(root2.children.isEmpty)
    }

    @Test("build with array via for loop")
    func buildWithArray() {
        let names = ["a", "b", "c"]
        let root = XMLElement.build("root") {
            for name in names {
                XMLElement.build(name)
            }
        }
        #expect(root.children.count == 3)
        #expect(root.elementChildren.map(\.name) == ["a", "b", "c"])
    }

    @Test("build with mixed content")
    func buildMixedContent() {
        let root = XMLElement.build("root") {
            "Some text"
            XMLElement.build("child")
            XMLNode.comment(" a comment ")
        }
        #expect(root.children.count == 3)
        #expect(root.children[0].asText == "Some text")
        #expect(root.children[1].asElement?.name == "child")
        #expect(root.children[2].asComment == " a comment ")
    }

    @Test("build with if/else")
    func buildIfElse() {
        let useA = true
        let root = XMLElement.build("root") {
            if useA {
                XMLElement.build("a")
            } else {
                XMLElement.build("b")
            }
        }
        #expect(root.children.count == 1)
        #expect(root.children[0].asElement?.name == "a")
    }

    @Test("build with empty block produces no children")
    func buildEmptyBlock() {
        let root = XMLElement.build("root") {}
        #expect(root.name == "root")
        #expect(root.children.isEmpty)
    }
}
