import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `AIXM 5.1 time slices` {
  private typealias Doc = AIXM51Document

  private static func airportNames(_ slices: String...) throws -> [String] {
    let document = Doc.message(Doc.feature("AirportHeliport", uuid: "ahp", slices: slices))
    return try Fixtures.dataset(document: document).dataset.airports.map(\.name)
  }

  private static func airportSlice(
    _ name: String,
    interpretation: String = "BASELINE",
    sequence: Int = 1,
    correction: Int = 0,
    validFrom: String? = "2020-01-01T00:00:00Z",
    validUntil: String? = nil,
    lifetimeEnd: String? = nil
  ) -> String {
    Doc.slice(
      "AirportHeliport",
      interpretation: interpretation,
      sequence: sequence,
      correction: correction,
      validFrom: validFrom,
      validUntil: validUntil,
      lifetimeEnd: lifetimeEnd,
      properties: [Doc.value("designator", "XXAA"), Doc.value("name", name)]
    )
  }

  @Test
  func `reads the slice in effect on the effective date`() throws {
    let (dataset, _) = try Fixtures.dataset(Fixtures.timeSlices)
    #expect(dataset.airports.map(\.name) == ["CURRENT NAME"])
  }

  @Test
  func `reads a later slice once it takes effect`() throws {
    let december = Fixtures.effectiveDate.addingTimeInterval(60 * 60 * 24 * 40)
    let (dataset, _) = try Fixtures.dataset(Fixtures.timeSlices, effectiveDate: december)
    #expect(dataset.airports.map(\.name) == ["FUTURE NAME"])
  }

  @Test
  func `includes a feature before its lifetime ends`() throws {
    let january = Fixtures.effectiveDate.addingTimeInterval(-60 * 60 * 24 * 300)
    let (dataset, _) = try Fixtures.dataset(Fixtures.timeSlices, effectiveDate: january)
    #expect(dataset.airports.map(\.designator) == ["XXAA", "XXBB"])
  }

  @Test
  func `drops a feature whose lifetime ends on the effective date`() throws {
    #expect(
      try Self.airportNames(Self.airportSlice("CLOSED", lifetimeEnd: "2026-10-29T00:00:00Z"))
        .isEmpty
    )
  }

  @Test
  func `ignores a slice whose valid time ends on the effective date`() throws {
    let names = try Self.airportNames(
      Self.airportSlice("OLD", sequence: 2, validUntil: "2026-10-29T00:00:00Z"),
      Self.airportSlice("CURRENT")
    )
    #expect(names == ["CURRENT"])
  }

  @Test
  func `reads a slice that begins on the effective date`() throws {
    let names = try Self.airportNames(
      Self.airportSlice("OLD"),
      Self.airportSlice("NEW", sequence: 2, validFrom: "2026-10-29T00:00:00Z")
    )
    #expect(names == ["NEW"])
  }

  @Test
  func `reads a slice with no valid time as always in effect`() throws {
    #expect(try Self.airportNames(Self.airportSlice("UNDATED", validFrom: nil)) == ["UNDATED"])
  }

  @Test(arguments: ["TEMPDELTA", "PERMDELTA"])
  func `ignores slices that are not a baseline or snapshot`(_ interpretation: String) throws {
    let names = try Self.airportNames(
      Self.airportSlice("BASELINE"),
      Self.airportSlice("DELTA", interpretation: interpretation, sequence: 2)
    )
    #expect(names == ["BASELINE"])
  }

  @Test
  func `reads a snapshot slice`() throws {
    #expect(
      try Self.airportNames(Self.airportSlice("SNAPSHOT", interpretation: "SNAPSHOT")) == [
        "SNAPSHOT"
      ]
    )
  }

  @Test
  func `takes the highest sequence number, then the highest correction number`() throws {
    let names = try Self.airportNames(
      Self.airportSlice("SECOND CORRECTED", sequence: 2, correction: 1),
      Self.airportSlice("FIRST", sequence: 1, correction: 5),
      Self.airportSlice("SECOND", sequence: 2, correction: 0)
    )
    #expect(names == ["SECOND CORRECTED"])
  }

  @Test
  func `reports a feature with no identifier`() throws {
    let document = Doc.message(
      Doc.feature("Runway", uuid: nil, localID: "rwy", Doc.value("designator", "09/27"))
    )
    let (dataset, problems) = try Fixtures.dataset(document: document)
    #expect(dataset.airports.isEmpty)
    #expect(problems == [.missing(feature: "Runway", id: "rwy", field: "gml:identifier")])
  }
}
