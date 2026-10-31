public import Foundation

/// Errors that stop a data set from being read at all.
public enum AIXMError: Error, LocalizedError, Sendable {

  /// The file could not be opened.
  case fileNotFound(URL)

  /// The document is not well-formed XML.
  case malformedXML(reason: String, line: Int)

  /// The document's root element is neither an AIXM 5.1 message nor an OFMX snapshot.
  case unrecognizedFormat(rootElement: String?)

  public var errorDescription: String? {
    switch self {
      case .fileNotFound:
        String(localized: "AIXM file was not found.", bundle: .module)
      case .malformedXML, .unrecognizedFormat:
        String(localized: "AIXM data could not be read.", bundle: .module)
    }
  }

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

  /// A required value is missing.
  case missingValue(feature: String, id: String, field: String)

  /// A value could not be parsed.
  case invalidValue(feature: String, id: String, field: String, value: String)

  /// A reference to another feature could not be resolved.
  case unresolvedReference(feature: String, id: String, reference: String)

  public var errorDescription: String? {
    String(localized: "An AIXM record could not be read.", bundle: .module)
  }

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
