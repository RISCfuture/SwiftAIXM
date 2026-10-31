public import Foundation

/// Errors that stop a data set from being read at all.
public enum AIXMError: Error, LocalizedError, Sendable {

  /// The file does not exist or could not be opened.
  case fileNotFound(URL)

  /**
   The document is not well-formed XML, or ends before its root element is closed.

   - Parameters:
     - reason: The XML parser's description of the problem.
     - line: The line the parser stopped at.
   */
  case malformedXML(reason: String, line: Int)

  /// The document's root element is neither an AIXM 5.1 message nor an OFMX snapshot.
  case unrecognizedFormat(rootElement: String?)

  /// A general description of the error: whether the file was missing or its contents could
  /// not be read.
  public var errorDescription: String? {
    switch self {
      case .fileNotFound:
        String(localized: "AIXM file was not found.", bundle: .module)
      case .malformedXML, .unrecognizedFormat:
        String(localized: "AIXM data could not be read.", bundle: .module)
    }
  }

  /// The specific problem: the path that could not be opened, the line where the XML is
  /// malformed, or the root element that was not recognized.
  public var failureReason: String? {
    switch self {
      case .fileNotFound(let url):
        String(localized: "No file could be opened at “\(url.path)”.", bundle: .module)
      case let .malformedXML(reason, line):
        String(
          localized:
            "The XML is malformed at line \(String(line)): \(reason)",
          bundle: .module
        )
      case .unrecognizedFormat(let rootElement):
        if let rootElement {
          String(
            localized:
              "The root element “\(rootElement)” is not an AIXM 5.1 message or an OFMX snapshot.",
            bundle: .module
          )
        } else {
          String(localized: "The document has no root element.", bundle: .module)
        }
    }
  }
}

/// Problems with a single record. The record is skipped, or the affected value omitted,
/// and the rest of the data set is still read.
public enum AIXMRecordError: Error, LocalizedError, Sendable {

  /**
   A required value is missing.

   - Parameters:
     - feature: The feature's element name, such as `RunwayDirection` or `Rdn`.
     - id: The record's identifier, where it has one.
     - field: The element that is missing.
   */
  case missingValue(feature: String, id: String, field: String)

  /**
   A value could not be parsed, or is a code its code list does not contain.

   - Parameters:
     - feature: The feature's element name, such as `RunwayDirection` or `Rdn`.
     - id: The record's identifier, where it has one.
     - field: The element holding the value.
     - value: The value as written in the data set.
   */
  case invalidValue(feature: String, id: String, field: String, value: String)

  /**
   An AIXM 5.1 reference to another feature could not be resolved: a local `#` reference to
   no feature in the message, or an `xlink:href` in a form that is not recognized.

   - Parameters:
     - feature: The referring feature's element name.
     - id: The referring record's identifier.
     - reference: The `xlink:href` as written in the data set.
   */
  case unresolvedReference(feature: String, id: String, reference: String)

  /// A general description of the error, the same for every record error.
  public var errorDescription: String? {
    String(localized: "An AIXM record could not be read.", bundle: .module)
  }

  /// The specific problem, naming the feature, the record's identifier, and the field, value,
  /// or reference at fault.
  public var failureReason: String? {
    switch self {
      case let .missingValue(feature, id, field):
        String(localized: "\(feature) “\(id)” has no \(field).", bundle: .module)
      case let .invalidValue(feature, id, field, value):
        String(
          localized: "\(feature) “\(id)” has an invalid \(field): “\(value)”.",
          bundle: .module
        )
      case let .unresolvedReference(feature, id, reference):
        String(
          localized: "\(feature) “\(id)” refers to “\(reference)”, which is not in the data set.",
          bundle: .module
        )
    }
  }
}
