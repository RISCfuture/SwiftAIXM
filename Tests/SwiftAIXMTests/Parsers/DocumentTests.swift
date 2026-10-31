import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `Data set documents` {
  private static let byteOrderMark = Data([0xEF, 0xBB, 0xBF])

  private static func fixtureData(_ name: String) throws -> Data {
    try Data(contentsOf: Fixtures.url(name))
  }

  @Test
  func `detects the format from the root element`() throws {
    let message = try AIXMDataset(data: Data(AIXM51Document.message().utf8))
    let snapshot = try AIXMDataset(data: Data(OFMXDocument.snapshot().utf8))
    #expect(message.format == .AIXM51)
    #expect(snapshot.format == .OFMX)
  }

  @Test
  func `reads a document that starts with a byte order mark`() throws {
    let data = try Self.byteOrderMark + Self.fixtureData(Fixtures.openFlightmaps)
    let dataset = try AIXMDataset(data: data, effectiveDate: Fixtures.effectiveDate)
    #expect(dataset.format == .OFMX)
    #expect(dataset.airports.count == 2)
  }

  @Test
  func `reads the same records from a file and from memory`() throws {
    let fromFile = try AIXMDataset(
      url: Fixtures.url(Fixtures.aerodrome),
      effectiveDate: Fixtures.effectiveDate
    )
    let fromMemory = try AIXMDataset(
      data: Self.fixtureData(Fixtures.aerodrome),
      effectiveDate: Fixtures.effectiveDate
    )
    #expect(fromFile.airports == fromMemory.airports)
  }

  @Test
  func `throws for a document that is not a data set`() {
    let error = #expect(throws: AIXMError.self) {
      try AIXMDataset(data: Data("<html><body/></html>".utf8))
    }
    guard case .unrecognizedFormat(let root) = error else {
      Issue.record("Expected an unrecognized format, got \(String(describing: error))")
      return
    }
    #expect(root == "html")
  }

  @Test
  func `throws for a document with no root element`() {
    let error = #expect(throws: AIXMError.self) { try AIXMDataset(data: Data()) }
    guard case .unrecognizedFormat(let root) = error else {
      Issue.record("Expected an unrecognized format, got \(String(describing: error))")
      return
    }
    #expect(root == nil)
  }

  @Test
  func `throws for malformed XML`() {
    let error = #expect(throws: AIXMError.self) {
      try AIXMDataset(data: Data("<OFMX-Snapshot><Ahp></Rwy></OFMX-Snapshot>".utf8))
    }
    guard case .malformedXML = error else {
      Issue.record("Expected malformed XML, got \(String(describing: error))")
      return
    }
  }

  @Test
  func `throws for a truncated document`() throws {
    let data = try Self.fixtureData(Fixtures.openFlightmaps)
    let error = #expect(throws: AIXMError.self) {
      try AIXMDataset(data: data.prefix(data.count / 2))
    }
    guard case .malformedXML = error else {
      Issue.record("Expected malformed XML, got \(String(describing: error))")
      return
    }
  }

  @Test
  func `throws for a file that does not exist`() {
    let url = URL(fileURLWithPath: "/nonexistent/EG_AIP_DS_FULL.xml")
    let error = #expect(throws: AIXMError.self) { try AIXMDataset(url: url) }
    guard case .fileNotFound(let missing) = error else {
      Issue.record("Expected a missing file, got \(String(describing: error))")
      return
    }
    #expect(missing == url)
  }
}
