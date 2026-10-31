public import Foundation

#if canImport(FoundationXML)
  import FoundationXML
#endif

/**
 The aerodromes and obstacles in an AIXM data set.

 Reads AIXM 5.1 and 5.1.1 `AIXMBasicMessage` documents, as published in ICAO AIP and
 obstacle data sets, and open flightmaps OFMX snapshots. The format is detected from
 the document's root element. Documents are streamed, so very large files are read
 without holding them in memory.
 */
public struct AIXMDataset: Sendable, Codable {

  /// The format the data set was read from.
  public let format: Format

  /// The aerodromes in the data set, with their runways.
  public let airports: [Airport]

  /// The obstacles in the data set.
  public let obstacles: [Obstacle]

  /**
   Reads a data set from a file.

   - Parameters:
     - url: The data set file.
     - effectiveDate: The date whose data to read. AIXM 5.1 features carry time slices,
       and only the one in effect on this date is used.
     - errorCallback: Called for each record that can't be read in full. The record is
       skipped or the affected value omitted, and reading continues.
   - Throws: ``AIXMError`` if the file can't be opened or isn't a recognized data set.
   */
  public init(
    url: URL,
    effectiveDate: Date = .now,
    errorCallback: ((any Error) -> Void)? = nil
  ) throws(AIXMError) {
    guard let stream = InputStream(url: url) else { throw .fileNotFound(url) }
    try self.init(
      parser: XMLParser(stream: stream),
      effectiveDate: effectiveDate,
      errorCallback: errorCallback
    )
  }

  /**
   Reads a data set from memory.

   - Parameters:
     - data: The data set document.
     - effectiveDate: The date whose data to read. AIXM 5.1 features carry time slices,
       and only the one in effect on this date is used.
     - errorCallback: Called for each record that can't be read in full. The record is
       skipped or the affected value omitted, and reading continues.
   - Throws: ``AIXMError`` if the data isn't a recognized data set.
   */
  public init(
    data: Data,
    effectiveDate: Date = .now,
    errorCallback: ((any Error) -> Void)? = nil
  ) throws(AIXMError) {
    try self.init(
      parser: XMLParser(data: data),
      effectiveDate: effectiveDate,
      errorCallback: errorCallback
    )
  }

  private init(
    parser: XMLParser,
    effectiveDate: Date,
    errorCallback: ((any Error) -> Void)?
  ) throws(AIXMError) {
    let report = errorCallback ?? { _ in }
    let stream = FeatureStream { rootName in
      Format(rootElement: rootName)?.builder(effectiveDate: effectiveDate, report: report)
    }
    #if canImport(Darwin)
      // Darwin declares `XMLParser.delegate` unowned(unsafe); `stream` outlives the parse below.
      unsafe parser.delegate = stream
    #else
      parser.delegate = stream
    #endif
    let succeeded = parser.parse()

    guard let builder = stream.builder, let format = Format(rootElement: stream.rootName) else {
      throw .unrecognizedFormat(rootElement: stream.rootName)
    }
    guard succeeded, stream.isComplete else {
      throw .malformedXML(
        reason: parser.parserError?.localizedDescription ?? "",
        line: parser.lineNumber
      )
    }

    let (airports, obstacles) = builder.finish()
    self.format = format
    self.airports = airports
    self.obstacles = obstacles
  }

  /// A data set format.
  public enum Format: String, Sendable, Codable {

    /// An AIXM 5.1 or 5.1.1 `AIXMBasicMessage`.
    case AIXM51

    /// An open flightmaps OFMX snapshot.
    case OFMX

    init?(rootElement: String?) {
      switch rootElement {
        case "AIXMBasicMessage": self = .AIXM51
        case "OFMX-Snapshot": self = .OFMX
        default: return nil
      }
    }

    func builder(effectiveDate: Date, report: @escaping (any Error) -> Void) -> any FeatureBuilder {
      switch self {
        case .AIXM51: AIXM51Builder(effectiveDate: effectiveDate, report: report)
        case .OFMX: OFMXBuilder(report: report)
      }
    }
  }
}
