import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `AIXM 5.1 aerodromes` {
  private let dataset: AIXMDataset

  private var southend: Airport {
    get throws { try #require(dataset.airports.first) }
  }

  init() throws {
    let (dataset, errors) = try Fixtures.dataset(Fixtures.aerodrome)
    #expect(errors.isEmpty)
    self.dataset = dataset
  }

  private func direction(_ designator: String) throws -> RunwayDirection {
    try #require(southend.runways.first?.directions.first { $0.designator == designator })
  }

  @Test
  func `reads the aerodrome`() throws {
    #expect(dataset.format == .AIXM51)
    let southend = try southend
    #expect(southend.designator == "EGMC")
    #expect(southend.ICAOIdentifier == "EGMC")
    #expect(southend.name == "SOUTHEND")
    #expect(southend.type == .aerodrome)
    #expect(
      southend.referencePoint == Location(latitudeDeg: 51.570412389, longitudeDeg: 0.693294083)
    )
    #expect(southend.elevation == Measurement(value: 58.4, unit: .feet))
  }

  @Test
  func `links the runway and its directions`() throws {
    let runway = try #require(southend.runways.only)
    #expect(runway.designator == "05/23")
    #expect(runway.isFixedWing)
    #expect(runway.length == Measurement(value: 1856.28, unit: .meters))
    #expect(runway.width == Measurement(value: 36, unit: .meters))
    #expect(runway.composition == .asphalt)
    #expect(runway.directions.map(\.designator) == ["05", "23"])
  }

  @Test
  func `places the threshold and displaced threshold by role`() throws {
    let runway05 = try direction("05"), runway23 = try direction("23")
    #expect(
      runway05.threshold?.location == Location(latitudeDeg: 51.565924361, longitudeDeg: 0.683322972)
    )
    #expect(runway05.threshold?.elevation == Measurement(value: 55.18, unit: .feet))
    #expect(runway05.displacedThreshold == nil)
    #expect(runway23.threshold == nil)
    #expect(runway23.displacedThreshold?.elevation == Measurement(value: 38.14, unit: .feet))
    #expect(runway05.touchdownZoneElevation == Measurement(value: 55.18, unit: .feet))
  }

  @Test
  func `takes the full-length declared distances over intersection and scheduled ones`() throws {
    let distances = try direction("05").declaredDistances
    #expect(distances.TORA == Measurement(value: 1738.93, unit: .meters))
    #expect(distances.TODA == Measurement(value: 1799, unit: .meters))
    #expect(distances.ASDA == Measurement(value: 1738.93, unit: .meters))
    #expect(distances.LDA == Measurement(value: 1603.96, unit: .meters))
  }

  @Test
  func `joins each glide path to its runway direction through the navaid`() throws {
    #expect(try direction("05").glidepath?.angle == Measurement(value: 3.5, unit: .degrees))
    #expect(try direction("23").glidepath?.angle == Measurement(value: 3, unit: .degrees))
    #expect(
      try direction("23").glidepath?.referenceDatumHeight == Measurement(value: 52, unit: .feet)
    )
  }
}

@Suite
struct `AIXM 5.1 time slices` {
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
}

extension Collection {
  /// The collection's single element, or `nil` if it has none or several.
  var only: Element? { count == 1 ? first : nil }
}
