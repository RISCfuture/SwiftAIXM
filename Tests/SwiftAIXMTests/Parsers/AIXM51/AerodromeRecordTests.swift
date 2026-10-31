import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `AIXM 5.1 aerodrome records` {
  private typealias Doc = AIXM51Document

  private static func airport(_ features: String...) throws -> (Airport?, [RecordProblem]) {
    try airport(features: features)
  }

  private static func airport(features: [String]) throws -> (Airport?, [RecordProblem]) {
    let (dataset, problems) = try Fixtures.dataset(document: Doc.message(features: features))
    return (dataset.airports.only, problems)
  }

  @Test
  func `reads the aerodrome's identification and reference point`() throws {
    let (airport, problems) = try Self.airport(
      Doc.airport(
        Doc.value("name", "TEST FIELD"),
        Doc.value("locationIndicatorICAO", "XXAA"),
        Doc.value("designatorIATA", "XXA"),
        Doc.value("type", "AH"),
        Doc.value("fieldElevation", "120", uom: "FT"),
        Doc.value("magneticVariation", "-1.5"),
        "<aixm:servedCity><aixm:City><aixm:name>TESTVILLE</aixm:name></aixm:City></aixm:servedCity>",
        Doc.elevatedPoint("ARP", "51.5 -0.25")
      )
    )
    let field = try #require(airport)
    #expect(problems.isEmpty)
    #expect(field.ICAOIdentifier == "XXAA")
    #expect(field.IATAIdentifier == "XXA")
    #expect(field.city == "TESTVILLE")
    #expect(field.type == .aerodromeAndHeliport)
    #expect(field.magneticVariation == Measurement(value: -1.5, unit: .degrees))
    #expect(
      field.referencePoint
        == Location(
          latitudeDeg: 51.5,
          longitudeDeg: -0.25,
          elevation: Measurement(value: 120, unit: .feet)
        )
    )
  }

  @Test
  func `names an aerodrome without a name by its designator`() throws {
    let (airport, _) = try Self.airport(Doc.airport())
    #expect(airport?.name == "XXAA")
  }

  @Test
  func `reports an unknown aerodrome type and reads the rest of the aerodrome`() throws {
    let (airport, problems) = try Self.airport(Doc.airport(Doc.value("type", "SEAPLANE")))
    #expect(airport?.designator == "XXAA")
    #expect(airport?.type == nil)
    #expect(
      problems == [
        .invalid(feature: "AirportHeliport", id: "ahp", field: "type", value: "SEAPLANE")
      ]
    )
  }

  @Test
  func `reports features without a designator and skips them`() throws {
    let (airport, problems) = try Self.airport(features: [
      Doc.airport(designator: nil),
      Doc.airport(uuid: "ahp2"),
      Doc.runway(airport: "urn:uuid:ahp2", designator: nil),
      Doc.direction(uuid: "rdn", designator: nil)
    ])
    #expect(airport?.runways.isEmpty == true)
    #expect(
      problems == [
        .missing(feature: "AirportHeliport", id: "ahp", field: "designator"),
        .missing(feature: "Runway", id: "rwy", field: "designator"),
        .missing(feature: "RunwayDirection", id: "rdn", field: "designator")
      ]
    )
  }

  @Test
  func `reads a final approach and takeoff area as not fixed-wing`() throws {
    let (airport, _) = try Self.airport(
      Doc.airport(),
      Doc.runway(designator: "H1", Doc.value("type", "FATO")),
      Doc.runway(uuid: "rwy2", designator: "09/27", Doc.value("type", "RWY"))
    )
    let runways = try #require(airport?.runways)
    #expect(runways.map(\.designator) == ["09/27", "H1"])
    #expect(runways.map(\.isFixedWing) == [true, false])
  }

  @Test
  func `reads the runway's dimensions and surface`() throws {
    let (airport, problems) = try Self.airport(
      Doc.airport(),
      Doc.runway(
        Doc.value("nominalLength", "1200", uom: "M"),
        Doc.value("nominalWidth", "98", uom: "FT"),
        """
        <aixm:surfaceProperties><aixm:SurfaceCharacteristics>
          <aixm:composition>ASPH_GRASS</aixm:composition>
        </aixm:SurfaceCharacteristics></aixm:surfaceProperties>
        """
      )
    )
    let runway = try #require(airport?.runways.only)
    #expect(problems.isEmpty)
    #expect(runway.length == Measurement(value: 1200, unit: .meters))
    #expect(runway.width == Measurement(value: 98, unit: .feet))
    #expect(runway.composition == .asphaltAndGrass)
  }

  @Test
  func `reads each direction's bearings and points by role`() throws {
    let (airport, problems) = try Self.airport(
      Doc.airport(),
      Doc.runway(),
      Doc.direction(
        uuid: "rdn27",
        designator: "27",
        Doc.value("trueBearing", "268.5"),
        Doc.value("magneticBearing", "270"),
        Doc.value("elevationTDZ", "110", uom: "FT")
      ),
      Doc.direction(uuid: "rdn09", designator: "09"),
      Doc.centrelinePoint(
        uuid: "thr27",
        direction: "urn:uuid:rdn27",
        role: "THR",
        Doc.elevatedPoint("location", "51.5 -0.2", elevation: "112")
      ),
      Doc.centrelinePoint(
        uuid: "end27",
        direction: "urn:uuid:rdn27",
        role: "END",
        Doc.elevatedPoint("location", "51.5 -0.3")
      )
    )
    let directions = try #require(airport?.runways.only?.directions)
    #expect(problems.isEmpty)
    #expect(directions.map(\.designator) == ["09", "27"])

    let runway27 = directions[1]
    #expect(runway27.trueBearing == Measurement(value: 268.5, unit: .degrees))
    #expect(runway27.magneticBearing == Measurement(value: 270, unit: .degrees))
    #expect(runway27.touchdownZoneElevation == Measurement(value: 110, unit: .feet))
    #expect(
      runway27.threshold
        == Location(
          latitudeDeg: 51.5,
          longitudeDeg: -0.2,
          elevation: Measurement(value: 112, unit: .feet)
        )
    )
    #expect(runway27.end == Location(latitudeDeg: 51.5, longitudeDeg: -0.3))
    #expect(runway27.displacedThreshold == nil)
  }

  @Test
  func `reports an unknown centre-line point role`() throws {
    let (_, problems) = try Self.airport(
      Doc.airport(),
      Doc.runway(),
      Doc.direction(uuid: "rdn", designator: "09"),
      Doc.centrelinePoint(uuid: "pt", direction: "urn:uuid:rdn", role: "MIDPOINT")
    )
    #expect(
      problems == [
        .invalid(feature: "RunwayCentrelinePoint", id: "pt", field: "role", value: "MIDPOINT")
      ]
    )
  }
}
