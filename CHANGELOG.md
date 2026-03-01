# Changelog

All notable changes to XMLKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-03-01

Initial release.

### Added

- Parse XML from `String` or UTF-8 bytes (`Data`) into an in-memory element tree
- Serialize elements back to well-formed XML strings
- `XMLElement` struct with name, prefix, namespace, attributes, and children
- `XMLNode` enum with cases for element, text, comment, CDATA, and processing instruction
- Namespace-aware parsing: default namespaces, prefixed namespaces, undeclaration, shadowing
- Full XML 1.0 entity handling: named (`&lt;`, `&gt;`, `&amp;`, `&quot;`, `&apos;`), decimal (`&#169;`), and hex (`&#xA9;`)
- CDATA section parsing and round-trip writing (with `]]>` splitting)
- Comment parsing with `--` validation and sanitization on write
- Processing instruction support
- DOCTYPE declaration skipping
- Child element access: `getChild`, `withMutableChild`, `takeChild`, `indexOfChild`, subscripts
- `getText()` for concatenated text/CDATA content
- `XMLElementPredicate` protocol with `String` and `NameAndNamespace` conformances
- `XMLBuilder` result builder DSL for declarative tree construction
- `ParserConfig` with `ignoreComments` and `ignoreProcessingInstructions` options
- `EmitterConfig` with declaration, indentation, indent string, and line separator options
- `XMLNamespaceMap` for namespace prefix-to-URI mappings
- `XMLParseError` with line and column numbers for all parse errors
- All types conform to `Sendable` (Swift 6.0 strict concurrency)
- Line ending normalization (`\r\n` and `\r` to `\n`)
- UTF-8 BOM stripping
- Attribute value whitespace normalization
- Duplicate attribute detection
- 223 tests across 11 suites
