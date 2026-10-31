import Foundation

#if canImport(FoundationXML)
  import FoundationXML
#endif

/// Turns the features of one data set format into model records, one feature at a time.
protocol FeatureBuilder: AnyObject {

  /// The local names of the elements this builder consumes.
  var featureNames: Set<String> { get }

  /// Consumes one feature element and everything below it.
  func consume(_ feature: XMLNode)

  /// Links the consumed features into model records.
  func finish() -> (airports: [Airport], obstacles: [Obstacle])
}

/**
 Streams an XML document, capturing each element a ``FeatureBuilder`` wants as a small
 tree and handing it over before discarding it.

 The builder is chosen from the document's root element, so a single pass both detects
 the format and parses it. Only one feature is held in memory at a time.
 */
final class FeatureStream: NSObject, XMLParserDelegate {
  private let makeBuilder: (String) -> (any FeatureBuilder)?
  private(set) var builder: (any FeatureBuilder)?
  private(set) var rootName: String?
  private var stack = [XMLNode]()
  private var depth = 0

  /// Whether every element opened, including the root, was closed. Some XML parsers
  /// report success for a truncated document.
  var isComplete: Bool { rootName != nil && depth == 0 }

  init(makeBuilder: @escaping (String) -> (any FeatureBuilder)?) {
    self.makeBuilder = makeBuilder
  }

  private static func localName(_ qualifiedName: String) -> String {
    qualifiedName.split(separator: ":").last.map(String.init) ?? qualifiedName
  }

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI _: String?,
    qualifiedName _: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    let name = Self.localName(elementName)
    depth += 1
    guard rootName != nil else {
      rootName = name
      builder = makeBuilder(name)
      if builder == nil { parser.abortParsing() }
      return
    }

    if stack.isEmpty {
      guard builder?.featureNames.contains(name) == true else { return }
    }

    let attributes = Dictionary(
      attributeDict.map { (Self.localName($0.key), $0.value) },
      uniquingKeysWith: { first, _ in first }
    )
    let node = XMLNode(name: name, attributes: attributes)
    stack.last?.append(child: node)
    stack.append(node)
  }

  func parser(
    _: XMLParser,
    didEndElement _: String,
    namespaceURI _: String?,
    qualifiedName _: String?
  ) {
    depth -= 1
    guard let node = stack.popLast() else { return }
    if stack.isEmpty { builder?.consume(node) }
  }

  func parser(_: XMLParser, foundCharacters string: String) {
    stack.last?.append(text: string)
  }
}
