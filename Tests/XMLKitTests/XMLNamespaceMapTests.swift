import Testing

@testable import XMLKit

@Suite("XMLNamespaceMap")
struct XMLNamespaceMapTests {

    @Test("Empty init creates empty map")
    func emptyInit() {
        let ns = XMLNamespaceMap()
        #expect(ns.mappings.isEmpty)
    }

    @Test("Dictionary init preserves mappings")
    func dictionaryInit() {
        let ns = XMLNamespaceMap(["h": "urn:html", "": "urn:default"])
        #expect(ns.mappings.count == 2)
        #expect(ns.mappings["h"] == "urn:html")
        #expect(ns.mappings[""] == "urn:default")
    }

    @Test("isEssentiallyEmpty for empty map")
    func isEssentiallyEmptyEmpty() {
        let ns = XMLNamespaceMap()
        #expect(ns.isEssentiallyEmpty)
    }

    @Test("isEssentiallyEmpty with only xml namespace")
    func isEssentiallyEmptyXmlOnly() {
        let ns = XMLNamespaceMap(["xml": "http://www.w3.org/XML/1998/namespace"])
        #expect(ns.isEssentiallyEmpty)
    }

    @Test("isEssentiallyEmpty with real namespace")
    func isEssentiallyEmptyNonEmpty() {
        let ns = XMLNamespaceMap(["": "urn:test"])
        #expect(!ns.isEssentiallyEmpty)
    }

    @Test("isEssentiallyEmpty with xml plus real namespace")
    func isEssentiallyEmptyMixed() {
        let ns = XMLNamespaceMap([
            "xml": "http://www.w3.org/XML/1998/namespace",
            "h": "urn:html",
        ])
        #expect(!ns.isEssentiallyEmpty)
    }

    @Test("Subscript get returns correct URI")
    func subscriptGet() {
        let ns = XMLNamespaceMap(["h": "urn:html"])
        #expect(ns["h"] == "urn:html")
        #expect(ns["missing"] == nil)
    }

    @Test("Subscript set updates mapping")
    func subscriptSet() {
        var ns = XMLNamespaceMap()
        ns["h"] = "urn:html"
        #expect(ns["h"] == "urn:html")
        ns["h"] = nil
        #expect(ns["h"] == nil)
    }

    @Test("uri(forPrefix:) returns correct URI")
    func uriForPrefix() {
        let ns = XMLNamespaceMap(["h": "urn:html", "": "urn:default"])
        #expect(ns.uri(forPrefix: "h") == "urn:html")
        #expect(ns.uri(forPrefix: "") == "urn:default")
        #expect(ns.uri(forPrefix: "missing") == nil)
    }

    @Test("Equality")
    func equality() {
        let ns1 = XMLNamespaceMap(["h": "urn:html"])
        let ns2 = XMLNamespaceMap(["h": "urn:html"])
        let ns3 = XMLNamespaceMap(["h": "urn:other"])
        #expect(ns1 == ns2)
        #expect(ns1 != ns3)
    }

    @Test("Hashable conformance")
    func hashable() {
        let ns1 = XMLNamespaceMap(["h": "urn:html"])
        let ns2 = XMLNamespaceMap(["h": "urn:html"])
        let ns3 = XMLNamespaceMap(["f": "urn:furniture"])
        let set: Set<XMLNamespaceMap> = [ns1, ns2, ns3]
        #expect(set.count == 2)
    }
}
