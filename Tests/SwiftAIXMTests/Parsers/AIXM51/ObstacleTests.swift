import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `AIXM 5.1 obstacles` {
  @Test
  func `reads a point obstacle with its top elevation and height`() throws {
    let (dataset, errors) = try Fixtures.dataset(Fixtures.britishObstacles)
    #expect(errors.isEmpty)

    let obstacle = try #require(dataset.obstacles.only)
    #expect(obstacle.name == "UK0229G149F")
    #expect(obstacle.type == .transmissionLine)
    #expect(obstacle.isLighted == false)

    let part = try #require(obstacle.parts.only)
    #expect(part.geometry == .point(Location(latitudeDeg: 51.0665889, longitudeDeg: -3.6193167)))
    #expect(part.topElevation == Measurement(value: 977, unit: .feet))
    #expect(part.height == Measurement(value: 351, unit: .feet))
  }

  @Test
  func `reads longitude-first positions in the CRS84 reference system`() throws {
    let (dataset, _) = try Fixtures.dataset(Fixtures.swissObstacles)
    let tree = try #require(dataset.obstacles.first { $0.name == "245NW30434" })
    let part = try #require(tree.parts.only)
    #expect(part.geometry == .point(Location(latitudeDeg: 46.97553642, longitudeDeg: 8.37464869)))
    #expect(part.topElevation == Measurement(value: 571.6, unit: .meters))
  }

  @Test
  func `reads each span of a line as a line part`() throws {
    let (dataset, _) = try Fixtures.dataset(Fixtures.swissObstacles)
    let line = try #require(dataset.obstacles.first { $0.name == "TL25003645" })
    #expect(line.parts.count > 1)
    #expect(
      line.parts.first?.geometry
        == .line([
          Location(latitudeDeg: 47.20249911, longitudeDeg: 8.79264352),
          Location(latitudeDeg: 47.2023736, longitudeDeg: 8.79354691)
        ])
    )
  }

  @Test
  func `reports a structure whose parts are all nil`() throws {
    let (dataset, errors) = try Fixtures.dataset(Fixtures.swissObstacles)
    #expect(!dataset.obstacles.contains { $0.name == "263BE20020" })

    let error = try #require(errors.only as? AIXMRecordError)
    guard case let .missingValue(feature, _, field) = error else {
      Issue.record("Expected a missing value, got \(error)")
      return
    }
    #expect(feature == "VerticalStructure")
    #expect(field == "part")
  }
}

@Suite
struct `AIXM 5.1 obstacle records` {
  private typealias Doc = AIXM51Document

  private static func read(_ properties: String...) throws -> (Obstacle?, [RecordProblem]) {
    let document = Doc.message(
      Doc.feature(
        "VerticalStructure",
        uuid: "vs",
        slices: [Doc.slice("VerticalStructure", properties: properties)]
      )
    )
    let (dataset, problems) = try Fixtures.dataset(document: document)
    return (dataset.obstacles.only, problems)
  }

  private static func part(height: String? = nil, _ projection: String) -> String {
    """
    <aixm:part><aixm:VerticalStructurePart>
      \(height.map { Doc.value("verticalExtent", $0, uom: "M") } ?? "")
      \(projection)
    </aixm:VerticalStructurePart></aixm:part>
    """
  }

  private static func pointProjection(_ position: String, elevation: String? = nil) -> String {
    Doc.elevatedPoint("horizontalProjection_location", position, elevation: elevation)
  }

  private static func surfaceProjection(_ positions: String, elevation: String) -> String {
    """
    <aixm:horizontalProjection_surfaceExtent>
      <aixm:ElevatedSurface srsName="urn:ogc:def:crs:EPSG::4326">
        <gml:patches><gml:PolygonPatch><gml:exterior><gml:Ring><gml:curveMember><gml:Curve>
          \
    <gml:segments><gml:GeodesicString><gml:posList>\(positions)</gml:posList></gml:GeodesicString></gml:segments>
        </gml:Curve></gml:curveMember></gml:Ring></gml:exterior></gml:PolygonPatch></gml:patches>
        <aixm:elevation uom="M">\(elevation)</aixm:elevation>
      </aixm:ElevatedSurface>
    </aixm:horizontalProjection_surfaceExtent>
    """
  }

  private static func curveProjection(_ positions: [String]) -> String {
    """
    <aixm:horizontalProjection_linearExtent>
      <aixm:ElevatedCurve \
    srsName="urn:ogc:def:crs:OGC:1.3:CRS84"><gml:segments><gml:LineStringSegment>
        \(positions.map { "<gml:pos>\($0)</gml:pos>" }.joined())
      </gml:LineStringSegment></gml:segments></aixm:ElevatedCurve>
    </aixm:horizontalProjection_linearExtent>
    """
  }

  @Test
  func `reads a surface part with the elevation of its top`() throws {
    let (obstacle, problems) = try Self.read(
      Self.part(
        height: "21",
        Self.surfaceProjection("48.1 16.4 48.2 16.4 48.2 16.5 48.1 16.4", elevation: "302.9")
      )
    )
    let part = try #require(obstacle?.parts.only)
    #expect(problems.isEmpty)
    #expect(
      part.geometry
        == .surface([
          Location(latitudeDeg: 48.1, longitudeDeg: 16.4),
          Location(latitudeDeg: 48.2, longitudeDeg: 16.4),
          Location(latitudeDeg: 48.2, longitudeDeg: 16.5),
          Location(latitudeDeg: 48.1, longitudeDeg: 16.4)
        ])
    )
    #expect(part.topElevation == Measurement(value: 302.9, unit: .meters))
    #expect(part.height == Measurement(value: 21, unit: .meters))
  }

  @Test
  func `reads a line from individual positions in the curve's reference system`() throws {
    let (obstacle, _) = try Self.read(Self.part(Self.curveProjection(["8.1 47.1", "8.2 47.2"])))
    #expect(
      obstacle?.parts.only?.geometry
        == .line([
          Location(latitudeDeg: 47.1, longitudeDeg: 8.1),
          Location(latitudeDeg: 47.2, longitudeDeg: 8.2)
        ])
    )
    #expect(obstacle?.parts.only?.topElevation == nil)
  }

  @Test
  func `reads every part of a group`() throws {
    let (obstacle, _) = try Self.read(
      Doc.value("group", "YES"),
      Self.part(Self.pointProjection("47.1 8.1", elevation: "1500")),
      Self.part(Self.pointProjection("47.2 8.2", elevation: "1600"))
    )
    let parts = try #require(obstacle?.parts)
    #expect(
      parts.map(\.topElevation) == [
        Measurement(value: 1500, unit: .feet), Measurement(value: 1600, unit: .feet)
      ]
    )
  }

  @Test
  func `reports a point part whose position cannot be read and keeps the other parts`() throws {
    let (obstacle, problems) = try Self.read(
      Self.part(Self.pointProjection("47.1")),
      Self.part(Self.pointProjection("47.2 8.2"))
    )
    #expect(
      obstacle?.parts.only?.geometry == .point(Location(latitudeDeg: 47.2, longitudeDeg: 8.2))
    )
    #expect(
      problems == [
        .invalid(
          feature: "VerticalStructure",
          id: "vs",
          field: "horizontalProjection_location",
          value: "47.1"
        )
      ]
    )
  }

  @Test(arguments: [
    Doc.value("name", "NOTHING"),
    Self.part(height: "20", ""),
    Self.part(Self.surfaceProjection("", elevation: "300"))
  ])
  func `reports a structure with no part it can place`(_ properties: String) throws {
    let (obstacle, problems) = try Self.read(properties)
    #expect(obstacle == nil)
    #expect(problems == [.missing(feature: "VerticalStructure", id: "vs", field: "part")])
  }

  @Test(arguments: [("YES", true), ("NO", false), ("OTHER:UNKNOWN", nil)] as [(String, Bool?)])
  func `reads whether the structure is lit`(_ code: String, _ expected: Bool?) throws {
    let (obstacle, problems) = try Self.read(
      Doc.value("lighted", code),
      Self.part(Self.pointProjection("47.1 8.1"))
    )
    #expect(problems.isEmpty)
    #expect(obstacle?.isLighted == expected)
  }

  @Test
  func `reports unknown type and lighting codes and reads the rest of the structure`() throws {
    let (obstacle, problems) = try Self.read(
      Doc.value("type", "SKYSCRAPER"),
      Doc.value("lighted", "SOMETIMES"),
      Self.part(Self.pointProjection("47.1 8.1"))
    )
    #expect(obstacle?.type == nil)
    #expect(obstacle?.isLighted == nil)
    #expect(obstacle?.parts.count == 1)
    #expect(
      problems == [
        .invalid(feature: "VerticalStructure", id: "vs", field: "type", value: "SKYSCRAPER"),
        .invalid(feature: "VerticalStructure", id: "vs", field: "lighted", value: "SOMETIMES")
      ]
    )
  }
}
