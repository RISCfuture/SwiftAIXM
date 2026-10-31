import Foundation
import SwiftAIXM
import Testing

@Suite
struct `Error descriptions` {
  @Test
  func `gives the line of malformed XML without digit grouping`() throws {
    let reason = try #require(
      AIXMError.malformedXML(reason: "unclosed tag", line: 12_345).failureReason
    )
    #expect(reason.contains("12345"))
    #expect(reason.contains("unclosed tag"))
  }

  @Test
  func `names the root element of an unrecognized document`() throws {
    let named = try #require(AIXMError.unrecognizedFormat(rootElement: "html").failureReason)
    let unnamed = try #require(AIXMError.unrecognizedFormat(rootElement: nil).failureReason)
    #expect(named.contains("html"))
    #expect(unnamed != named)
  }

  @Test
  func `names the file that could not be opened`() throws {
    let url = URL(fileURLWithPath: "/data/EG_AIP_DS_FULL.xml")
    let error = AIXMError.fileNotFound(url)
    let reason = try #require(error.failureReason)
    #expect(reason.contains("/data/EG_AIP_DS_FULL.xml"))
    #expect(
      error.errorDescription != AIXMError.unrecognizedFormat(rootElement: nil).errorDescription
    )
  }

  @Test(arguments: [
    AIXMRecordError.missingValue(feature: "Runway", id: "rwy-1", field: "designator"),
    .invalidValue(feature: "Runway", id: "rwy-1", field: "designator", value: "XYZ"),
    .unresolvedReference(feature: "Runway", id: "rwy-1", reference: "#designator")
  ])
  func `identifies the record and the field or reference at fault`(_ error: AIXMRecordError) throws
  {
    let reason = try #require(error.failureReason)
    #expect(reason.contains("Runway"))
    #expect(reason.contains("rwy-1"))
    #expect(reason.contains("designator"))
    #expect(error.errorDescription != nil)
  }
}
