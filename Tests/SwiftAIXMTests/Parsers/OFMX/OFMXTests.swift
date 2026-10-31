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
      ljubljana.referencePoint
        == Location(
          latitudeDeg: 46.22444444,
          longitudeDeg: 14.45611111,
          elevation: Measurement(value: 388, unit: .meters)
        )
    )
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
      runway12.threshold == Location(latitudeDeg: 46.23249167, longitudeDeg: 14.44039167)
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
struct `OFMX records` {
  private typealias Doc = OFMXDocument

  private static func read(_ features: String...) throws -> (AIXMDataset, [RecordProblem]) {
    try Fixtures.dataset(document: Doc.snapshot(features: features))
  }

  /// Reads direction 09 of runway 09/27 at XXAA, with the given declared distances.
  private static func direction(_ distances: String...) throws -> (
    RunwayDirection?, [RecordProblem]
  ) {
    let features =
      [
        Doc.airport("XXAA"),
        Doc.runway("XXAA", "09/27"),
        Doc.direction(
          "XXAA",
          "09/27",
          "09",
          Doc.value("geoLat", "51.5N"),
          Doc.value("geoLong", "000.25W")
        )
      ] + distances
    let (dataset, problems) = try Fixtures.dataset(document: Doc.snapshot(features: features))
    return (dataset.airports.only?.runways.only?.directions.only, problems)
  }

  private static func distance(
    _ type: String,
    period: String = "A",
    _ value: String,
    unit: String = "M"
  ) -> String {
    Doc.declaredDistance(
      "XXAA",
      "09/27",
      "09",
      type: type,
      period: period,
      value: value,
      unit: unit
    )
  }

  private static func meters(_ value: Double) -> Measurement<UnitLength> {
    Measurement(value: value, unit: .meters)
  }

  @Test
  func `reads an aerodrome's details`() throws {
    let (dataset, problems) = try Self.read(
      Doc.airport(
        "XXAA",
        Doc.value("txtName", "TEST FIELD"),
        Doc.value("codeType", "GLD"),
        Doc.value("txtNameCitySer", "TESTVILLE"),
        Doc.value("valMagVar", "-2"),
        Doc.value("geoLat", "4715.5N"),
        Doc.value("geoLong", "01120.5E"),
        Doc.value("valElev", "1450"),
        Doc.value("uomDistVer", "FT")
      )
    )
    let airport = try #require(dataset.airports.only)
    #expect(problems.isEmpty)
    #expect(airport.id == "ahp-XXAA")
    #expect(airport.type == .gliderSite)
    #expect(airport.city == "TESTVILLE")
    #expect(airport.magneticVariation == Measurement(value: -2, unit: .degrees))
    #expect(airport.referencePoint?.elevation == Measurement(value: 1450, unit: .feet))
  }

  @Test
  func `reports an aerodrome with no code and skips it`() throws {
    let (dataset, problems) = try Self.read(Doc.airport(nil, Doc.value("txtName", "NAMELESS")))
    #expect(dataset.airports.isEmpty)
    #expect(problems == [.missing(feature: "Ahp", id: "ahp-", field: "codeId")])
  }

  @Test
  func `reports runways and directions without a designator`() throws {
    let (dataset, problems) = try Self.read(
      Doc.airport("XXAA"),
      Doc.runway("XXAA", nil),
      Doc.runway("XXAA", "09/27"),
      Doc.direction("XXAA", "09/27", nil)
    )
    #expect(dataset.airports.only?.runways.only?.directions.isEmpty == true)
    #expect(
      problems == [
        .missing(feature: "Rdn", id: "rdn-XXAA-", field: "RdnUid"),
        .missing(feature: "Rwy", id: "rwy-XXAA-", field: "RwyUid")
      ]
    )
  }

  @Test
  func `reports an unknown surface composition and reads the rest of the runway`() throws {
    let (dataset, problems) = try Self.read(
      Doc.airport("XXAA"),
      Doc.runway(
        "XXAA",
        "09/27",
        Doc.value("codeComposition", "TARMAC"),
        Doc.value("valLen", "800")
      )
    )
    let runway = try #require(dataset.airports.only?.runways.only)
    #expect(runway.composition == nil)
    #expect(
      problems == [
        .invalid(feature: "Rwy", id: "XXAA|09/27", field: "codeComposition", value: "TARMAC")
      ]
    )
  }

  @Test
  func `reads the declared distances for the direction`() throws {
    let (direction, problems) = try Self.direction(
      Self.distance("TORA", "1500"),
      Self.distance("TODA", "1600"),
      Self.distance("ASDA", "1550"),
      Self.distance("LDA", "4900", unit: "FT")
    )
    #expect(problems.isEmpty)
    #expect(
      direction?.declaredDistances
        == DeclaredDistances(
          TORA: Self.meters(1500),
          TODA: Self.meters(1600),
          ASDA: Self.meters(1550),
          LDA: Measurement(value: 4900, unit: .feet),
          thresholdDisplacement: nil
        )
    )
  }

  @Test
  func `takes all-day distances over daytime ones in either order`() throws {
    let (direction, _) = try Self.direction(
      Self.distance("TORA", period: "D", "1400"),
      Self.distance("TORA", period: "A", "1500"),
      Self.distance("LDA", period: "A", "1300"),
      Self.distance("LDA", period: "D", "1200")
    )
    #expect(direction?.declaredDistances.TORA == Self.meters(1500))
    #expect(direction?.declaredDistances.LDA == Self.meters(1300))
  }

  @Test
  func `takes daytime distances when there are no all-day ones, and ignores night-time ones`()
    throws
  {
    let (direction, problems) = try Self.direction(
      Self.distance("TORA", period: "N", "900"),
      Self.distance("TORA", period: "D", "1400"),
      Self.distance("LDA", period: "OTHER", "1000"),
      Self.distance("ASDA", period: "N", "800")
    )
    #expect(problems.isEmpty)
    #expect(direction?.declaredDistances.TORA == Self.meters(1400))
    #expect(direction?.declaredDistances.LDA == nil)
    #expect(direction?.declaredDistances.ASDA == nil)
  }

  @Test
  func `reports an unknown day period or distance type`() throws {
    let (direction, problems) = try Self.direction(
      Self.distance("TORA", period: "W", "1400"),
      Self.distance("STOPWAY", "60")
    )
    #expect(direction?.declaredDistances == DeclaredDistances.none)
    #expect(
      problems == [
        .invalid(feature: "Rdd", id: "XXAA|09/27|09", field: "codeDayPeriod", value: "W"),
        .invalid(feature: "Rdd", id: "XXAA|09/27|09", field: "codeType", value: "STOPWAY")
      ]
    )
  }

  @Test(arguments: ["", "YD"])
  func `reports a distance without a known unit`(_ unit: String) throws {
    let (direction, problems) = try Self.direction(Self.distance("TORA", "1400", unit: unit))
    #expect(direction?.declaredDistances.TORA == nil)
    #expect(
      problems == [.invalid(feature: "Rdd", id: "XXAA|09/27|09", field: "valDist", value: "1400")]
    )
  }

  @Test
  func `places the point at the threshold when the displacement is zero`() throws {
    let (direction, _) = try Self.direction(Self.distance("DPLM", "0"))
    #expect(direction?.threshold == Location(latitudeDeg: 51.5, longitudeDeg: -0.25))
    #expect(direction?.displacedThreshold == nil)
    #expect(direction?.declaredDistances.thresholdDisplacement == Self.meters(0))
  }

  @Test
  func `places the point at the displaced threshold when the threshold is displaced`() throws {
    let (direction, _) = try Self.direction(Self.distance("DPLM", "120"))
    #expect(direction?.threshold == nil)
    #expect(direction?.displacedThreshold == Location(latitudeDeg: 51.5, longitudeDeg: -0.25))
  }

  @Test
  func `reads a direction's visual glide slope`() throws {
    let (dataset, _) = try Self.read(
      Doc.airport("XXAA"),
      Doc.runway("XXAA", "09/27"),
      Doc.direction(
        "XXAA",
        "09/27",
        "27",
        Doc.value("valSlopeAngleGpVasis", "3.5"),
        Doc.value("valMeht", "15"),
        Doc.value("uomMeht", "M"),
        Doc.value("valElevTdz", "320"),
        Doc.value("uomElevTdz", "FT")
      )
    )
    let direction = try #require(dataset.airports.only?.runways.only?.directions.only)
    #expect(
      direction.visualGlideSlope
        == VisualGlideSlope(
          angle: Measurement(value: 3.5, unit: .degrees),
          minimumEyeHeightOverThreshold: Self.meters(15)
        )
    )
    #expect(direction.touchdownZoneElevation == Measurement(value: 320, unit: .feet))
  }

  @Test
  func `reads an obstacle`() throws {
    let (dataset, problems) = try Self.read(
      Doc.obstacle(
        mid: "obs",
        latitude: "471530N",
        longitude: "0083000E",
        Doc.value("txtName", "STACK"),
        Doc.value("codeType", "CHIMNEY"),
        Doc.value("codeLgt", "N"),
        Doc.value("valElev", "1800"),
        Doc.value("valHgt", "120"),
        Doc.value("uomDistVer", "FT")
      )
    )
    let obstacle = try #require(dataset.obstacles.only)
    #expect(problems.isEmpty)
    #expect(obstacle.id == "obs")
    #expect(obstacle.type == .stack)
    #expect(obstacle.isLighted == false)
    #expect(obstacle.parts.only?.topElevation == Measurement(value: 1800, unit: .feet))
    #expect(obstacle.parts.only?.height == Measurement(value: 120, unit: .feet))
    #expect(obstacle.parts.only?.geometry.locations.only?.longitudeDeg == 8.5)
  }

  @Test
  func `reports an obstacle without a position and skips it`() throws {
    let (dataset, problems) = try Self.read(
      Doc.obstacle(mid: "obs", latitude: "47.1N", longitude: nil)
    )
    #expect(dataset.obstacles.isEmpty)
    #expect(problems == [.missing(feature: "Obs", id: "obs", field: "ObsUid")])
  }

  @Test
  func `reports unknown obstacle type and lighting codes`() throws {
    let (dataset, problems) = try Self.read(
      Doc.obstacle(
        mid: "obs",
        latitude: "47.1N",
        longitude: "8.1E",
        Doc.value("codeType", "SKYSCRAPER"),
        Doc.value("codeLgt", "YES")
      )
    )
    #expect(dataset.obstacles.only?.type == nil)
    #expect(dataset.obstacles.only?.isLighted == nil)
    #expect(
      problems == [
        .invalid(feature: "Obs", id: "obs", field: "codeType", value: "SKYSCRAPER"),
        .invalid(feature: "Obs", id: "obs", field: "codeLgt", value: "YES")
      ]
    )
  }
}
