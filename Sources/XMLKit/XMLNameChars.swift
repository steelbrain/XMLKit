/// XML 1.0 name character validation.
///
/// Implements the exact Unicode ranges from the XML 1.0 specification
/// for `NameStartChar` and `NameChar` productions.
enum XMLNameChars {

    // XML 1.0 NameStartChar: ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6]
    // | [#xF8-#x2FF] | [#x370-#x37D] | [#x37F-#x1FFF] | [#x200C-#x200D]
    // | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF]
    // | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
    static func isNameStartChar(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else {
            return false
        }
        let sv = scalar.value
        switch sv {
        case 0x3A, 0x5F: return true
        case 0x41...0x5A, 0x61...0x7A: return true
        case 0xC0...0xD6, 0xD8...0xF6, 0xF8...0x2FF: return true
        case 0x370...0x37D, 0x37F...0x1FFF: return true
        case 0x200C...0x200D, 0x2070...0x218F: return true
        case 0x2C00...0x2FEF, 0x3001...0xD7FF: return true
        case 0xF900...0xFDCF, 0xFDF0...0xFFFD: return true
        case 0x10000...0xEFFFF: return true
        default: return false
        }
    }

    // XML 1.0 Char: #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
    static func isValidXMLChar(_ scalar: Unicode.Scalar) -> Bool {
        let sv = scalar.value
        switch sv {
        case 0x9, 0xA, 0xD: return true
        case 0x20...0xD7FF: return true
        case 0xE000...0xFFFD: return true
        case 0x10000...0x10FFFF: return true
        default: return false
        }
    }

    // XML 1.0 NameChar: NameStartChar | "-" | "." | [0-9] | #xB7
    // | [#x0300-#x036F] | [#x203F-#x2040]
    static func isNameChar(_ ch: Character) -> Bool {
        if isNameStartChar(ch) { return true }
        guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else {
            return false
        }
        let sv = scalar.value
        switch sv {
        case 0x2D, 0x2E, 0xB7: return true
        case 0x30...0x39: return true
        case 0x0300...0x036F, 0x203F...0x2040: return true
        default: return false
        }
    }
}
