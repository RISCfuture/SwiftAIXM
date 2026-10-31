import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `AIXM 5.1 references` {
  private typealias Doc = AIXM51Document

  private static func read(_ features: String...) throws -> (AIXMDataset, [RecordProblem]) {
    try Fixtures.dataset(document: Doc.message(features: features))
  }

  @Test
  func `resolves a urn uuid reference`() throws {
    let (dataset, problems) = try Self.read(Doc.airport(), Doc.runway(airport: "urn:uuid:ahp"))
    #expect(problems.isEmpty)
    #expect(dataset.airports.only?.runways.only?.designator == "09/27")
  }

  @Test
  func `resolves a local reference to a feature's gml id`() throws {
    let (dataset, problems) = try Self.read(Doc.airport(), Doc.runway(airport: "#ahp-ahp"))
    #expect(problems.isEmpty)
    #expect(dataset.airports.only?.runways.only?.designator == "09/27")
  }

  @Test
  func `resolves a local reference to a feature later in the message`() throws {
    let (dataset, problems) = try Self.read(Doc.runway(airport: "#ahp-ahp"), Doc.airport())
    #expect(problems.isEmpty)
    #expect(dataset.airports.only?.runways.count == 1)
  }

  @Test(arguments: ["#nowhere", "https://example.com/ahp"])
  func `reports a reference it cannot resolve and drops the referring record`(_ href: String)
    throws
  {
    let (dataset, problems) = try Self.read(Doc.airport(), Doc.runway(airport: href))
    #expect(dataset.airports.only?.runways.isEmpty == true)
    #expect(problems == [.unresolved(feature: "Runway", id: "rwy", reference: href)])
  }

  @Test
  func `reports a record with no reference to its parent`() throws {
    let (dataset, problems) = try Self.read(Doc.airport(), Doc.runway(airport: nil))
    #expect(dataset.airports.only?.runways.isEmpty == true)
    #expect(problems == [.missing(feature: "Runway", id: "rwy", field: "reference")])
  }

  @Test
  func `reports a runway direction whose runway is unresolved`() throws {
    let (dataset, problems) = try Self.read(
      Doc.airport(),
      Doc.runway(),
      Doc.direction(uuid: "rdn", runway: "#missing", designator: "09")
    )
    #expect(dataset.airports.only?.runways.only?.directions.isEmpty == true)
    #expect(problems == [.unresolved(feature: "RunwayDirection", id: "rdn", reference: "#missing")])
  }
}
