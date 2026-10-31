import Foundation

/// An element captured from the XML stream, with namespace prefixes removed from its own
/// name and its attributes' names.
final class XMLNode {
  let name: String
  let attributes: [String: String]
  private(set) var children = [XMLNode]()
  private var textBuffer = ""

  /// The element's text content, trimmed of surrounding whitespace.
  var text: String { textBuffer.trimmingCharacters(in: .whitespacesAndNewlines) }

  /// The element's text content, or `nil` if the element is empty or marked nil.
  var value: String? {
    guard attributes["nil"] != "true" else { return nil }
    let text = text
    return text.isEmpty ? nil : text
  }

  init(name: String, attributes: [String: String]) {
    self.name = name
    self.attributes = attributes
  }

  func append(child: XMLNode) {
    children.append(child)
  }

  func append(text: String) {
    textBuffer += text
  }

  /// The first child element with the given name.
  func child(_ name: String) -> XMLNode? {
    children.first { $0.name == name }
  }

  /// Every child element with the given name.
  func children(_ name: String) -> [XMLNode] {
    children.filter { $0.name == name }
  }

  /// The first element reached by following child names in order.
  func descendant(_ path: String...) -> XMLNode? {
    descendant(path)
  }

  func descendant(_ path: some Collection<String>) -> XMLNode? {
    guard let first = path.first else { return self }
    return child(first)?.descendant(path.dropFirst())
  }

  /// The text of the element reached by following child names in order.
  func value(_ path: String...) -> String? {
    descendant(path)?.value
  }

  /// Every element with the given name anywhere below this one.
  func descendants(named name: String) -> [XMLNode] {
    children.flatMap { child in
      (child.name == name ? [child] : []) + child.descendants(named: name)
    }
  }
}
