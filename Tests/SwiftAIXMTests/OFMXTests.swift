import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `OFMX snapshots` {
  private let dataset: AIXMDataset

  init() throws {
    let (dataset, errors) = try Fixtures.dataset(Fixtures.openFlightmaps)
    #expect(errors.isEmpty)
    self.dataset = dataset
  }

  private func airport(_ code: String) throws -> Airport {
    try #require(dataset.airports.first { $0.designator == code })
  }

  @Test
  func `reads aerodromes with hemisphere-suffixed coordinates`() throws {
    #expect(dataset.format == .OFMX)
    let ljubljana = try airport("LJLJ")
    #expect(ljubljana.ICAOIdentifier == "LJLJ")
    #expect(ljubljana.IATAIdentifier == "LJU")
    #expect(ljubljana.name == "LJUBLJANA / BRNIK")
    #expect(
      ljubljana.referencePoint == Location(latitudeDeg: 46.22444444, longitudeDeg: 14.45611111)
    )
    #expect(ljubljana.elevation == Measurement(value: 388, unit: .meters))
  }

  @Test
  func `links runways, directions, and declared distances by their natural keys`() throws {
    let runway = try #require(airport("LJLJ").runways.only)
    #expect(runway.designator == "12/30")
    #expect(runway.length == Measurement(value: 3300, unit: .meters))
    #expect(runway.composition == .asphalt)

    let runway12 = try #require(runway.directions.first)
    #expect(runway12.designator == "12")
    #expect(runway12.trueBearing == Measurement(value: 126, unit: .degrees))
    #expect(
      runway12.threshold?.location == Location(latitudeDeg: 46.23249167, longitudeDeg: 14.44039167)
    )
    #expect(runway12.declaredDistances.TORA == Measurement(value: 3300, unit: .meters))
    #expect(runway12.declaredDistances.LDA == Measurement(value: 3300, unit: .meters))
  }

  @Test
  func `places a direction's point at the displaced threshold when it is displaced`() throws {
    let runway33 = try #require(
      airport("LJPZ").runways.only?.directions.first { $0.designator == "33" }
    )
    #expect(runway33.threshold == nil)
    #expect(runway33.displacedThreshold != nil)
    #expect(
      runway33.declaredDistances.thresholdDisplacement == Measurement(value: 210, unit: .meters)
    )
  }

  @Test
  func `reads obstacles`() throws {
    let mast = try #require(dataset.obstacles.only)
    #expect(mast.type == .mast)
    #expect(mast.isLighted == true)
    #expect(mast.parts.only?.topElevation == Measurement(value: 848, unit: .feet))
    #expect(
      mast.parts.only?.geometry == .point(Location(latitudeDeg: 52.29638889, longitudeDeg: -2.105))
    )
  }
}

@Suite
struct `Hemisphere coordinates` {
  @Test(arguments: [
    ("47.26027778N", 47.26027778),
    ("011.34388889E", 11.34388889),
    ("33.5S", -33.5),
    ("4715.5N", 47.258_333_333_333_33),
    ("0112038.00W", -11.343_888_888_888_89)
  ])
  func `parses each notation`(_ text: String, _ expected: Double) throws {
    let value = try #require(ValueParsing.hemisphereCoordinate(text))
    #expect(abs(value - expected) < 1e-9)
  }

  @Test(arguments: ["", "47.5", "47.5X", "N"])
  func `rejects malformed coordinates`(_ text: String) {
    #expect(ValueParsing.hemisphereCoordinate(text) == nil)
  }
}

@Suite
struct `Data set formats` {
  @Test
  func `throws for a document that is not a data set`() {
    let data = Data("<html><body/></html>".utf8)
    #expect(throws: AIXMError.self) { try AIXMDataset(data: data) }
  }

  @Test
  func `throws for malformed XML`() {
    let data = Data("<OFMX-Snapshot><Ahp>".utf8)
    #expect(throws: AIXMError.self) { try AIXMDataset(data: data) }
  }
}
