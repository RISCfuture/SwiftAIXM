import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `AIXM 5.1 declared distances` {
  private typealias Doc = AIXM51Document

  private static func meters(_ value: Double) -> Measurement<UnitLength> {
    Measurement(value: value, unit: .meters)
  }

  /// Reads runway direction 09 with the given centre-line points on it.
  private static func direction(_ points: String...) throws -> (RunwayDirection, [RecordProblem]) {
    let features =
      [Doc.airport(), Doc.runway(), Doc.direction(uuid: "rdn", designator: "09")] + points
    let (dataset, problems) = try Fixtures.dataset(document: Doc.message(features: features))
    return (try #require(dataset.airports.only?.runways.only?.directions.only), problems)
  }

  private static func point(_ uuid: String, role: String?, _ distances: String...) -> String {
    Doc.centrelinePoint(uuid: uuid, direction: "urn:uuid:rdn", role: role, properties: distances)
  }

  @Test
  func `takes threshold distances over longer ones on points without a role`() throws {
    let (direction, _) = try Self.direction(
      Self.point("thr", role: "THR", Doc.declaredDistance("TORA", meters: 1500)),
      Self.point("other", role: nil, Doc.declaredDistance("TORA", meters: 1800))
    )
    #expect(direction.declaredDistances.TORA == Self.meters(1500))
  }

  @Test
  func `takes the threshold over the displaced threshold, which fills in the rest`() throws {
    let (direction, _) = try Self.direction(
      Self.point(
        "disthr",
        role: "DISTHR",
        Doc.declaredDistance("LDA", meters: 1200),
        Doc.declaredDistance("TORA", meters: 1400)
      ),
      Self.point("thr", role: "THR", Doc.declaredDistance("TORA", meters: 1500))
    )
    #expect(direction.declaredDistances.TORA == Self.meters(1500))
    #expect(direction.declaredDistances.LDA == Self.meters(1200))
  }

  @Test
  func `takes the longest distance across points without a role and their scheduled values`()
    throws
  {
    let (direction, _) = try Self.direction(
      Self.point(
        "full",
        role: nil,
        Doc.declaredDistance("TORA", meters: 1700, 1800),
        Doc.declaredDistance("ASDA", meters: 1750)
      ),
      Self.point("intersection", role: nil, Doc.declaredDistance("TORA", meters: 1100)),
      Self.point("start", role: "START", Doc.declaredDistance("ASDA", meters: 1600))
    )
    #expect(direction.declaredDistances.TORA == Self.meters(1800))
    #expect(direction.declaredDistances.ASDA == Self.meters(1750))
  }

  @Test
  func `fills distances the threshold lacks from points without a role`() throws {
    let (direction, _) = try Self.direction(
      Self.point("thr", role: "THR", Doc.declaredDistance("LDA", meters: 1600)),
      Self.point("other", role: nil, Doc.declaredDistance("TODA", meters: 1900))
    )
    #expect(direction.declaredDistances.LDA == Self.meters(1600))
    #expect(direction.declaredDistances.TODA == Self.meters(1900))
  }

  @Test
  func `reads every declared distance type`() throws {
    let (direction, problems) = try Self.direction(
      Self.point(
        "thr",
        role: "THR",
        Doc.declaredDistance("TORA", meters: 1),
        Doc.declaredDistance("TODA", meters: 2),
        Doc.declaredDistance("ASDA", meters: 3),
        Doc.declaredDistance("LDA", meters: 4),
        Doc.declaredDistance("DTHR", meters: 5),
        Doc.declaredDistance("TODAH", meters: 6)
      )
    )
    #expect(problems.isEmpty)
    #expect(
      direction.declaredDistances
        == DeclaredDistances(
          TORA: Self.meters(1),
          TODA: Self.meters(2),
          ASDA: Self.meters(3),
          LDA: Self.meters(4),
          thresholdDisplacement: Self.meters(5)
        )
    )
  }

  @Test
  func `reports an unknown declared distance type and reads the others`() throws {
    let (direction, problems) = try Self.direction(
      Self.point(
        "thr",
        role: "THR",
        Doc.declaredDistance("EMDA", meters: 100),
        Doc.declaredDistance("LDA", meters: 1600)
      )
    )
    #expect(direction.declaredDistances.LDA == Self.meters(1600))
    #expect(
      problems == [
        .invalid(feature: "RunwayCentrelinePoint", id: "thr", field: "type", value: "EMDA")
      ]
    )
  }

  @Test
  func `leaves out a declared distance with no value`() throws {
    let (direction, problems) = try Self.direction(
      Self.point("thr", role: "THR", Doc.declaredDistance("LDA"))
    )
    #expect(problems.isEmpty)
    #expect(direction.declaredDistances == .none)
  }
}
