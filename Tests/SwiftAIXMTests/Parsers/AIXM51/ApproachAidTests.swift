import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `AIXM 5.1 approach aids` {
  private typealias Doc = AIXM51Document

  private static func directions(_ features: String...) throws -> (
    [RunwayDirection], [RecordProblem]
  ) {
    let all =
      [
        Doc.airport(),
        Doc.runway(),
        Doc.direction(uuid: "rdn09", designator: "09"),
        Doc.direction(uuid: "rdn27", designator: "27")
      ] + features
    let (dataset, problems) = try Fixtures.dataset(document: Doc.message(features: all))
    return (dataset.airports.only?.runways.only?.directions ?? [], problems)
  }

  private static func navaid(_ uuid: String, equipment: [String], directions: [String]) -> String {
    Doc.feature(
      "Navaid",
      uuid: uuid,
      slices: [
        Doc.slice(
          "Navaid",
          properties: equipment.map {
            """
            <aixm:navaidEquipment><aixm:NavaidComponent>
              \(Doc.reference("theNavaidEquipment", $0))
            </aixm:NavaidComponent></aixm:navaidEquipment>
            """
          } + directions.map { Doc.reference("runwayDirection", $0) }
        )
      ]
    )
  }

  @Test
  func `joins a glide path to the directions its navaid serves`() throws {
    let (directions, problems) = try Self.directions(
      Doc.feature("Localizer", uuid: "loc"),
      Doc.feature(
        "Glidepath",
        uuid: "gp",
        localID: "gp-local",
        Doc.value("slope", "3.25"),
        Doc.value("rdh", "15.5", uom: "M")
      ),
      Self.navaid("ils", equipment: ["urn:uuid:loc", "#gp-local"], directions: ["urn:uuid:rdn27"])
    )
    #expect(problems.isEmpty)
    #expect(
      directions.map(\.glidepath) == [
        nil,
        Glidepath(
          angle: Measurement(value: 3.25, unit: .degrees),
          referenceDatumHeight: Measurement(value: 15.5, unit: .meters)
        )
      ]
    )
  }

  @Test
  func `leaves the glide path out for a navaid without one`() throws {
    let (directions, problems) = try Self.directions(
      Self.navaid("vor", equipment: ["urn:uuid:vor-equipment"], directions: ["urn:uuid:rdn09"])
    )
    #expect(problems.isEmpty)
    #expect(directions.allSatisfy { $0.glidepath == nil })
  }

  @Test
  func `attaches a visual glide slope indicator to each direction it serves`() throws {
    let (directions, problems) = try Self.directions(
      Doc.feature(
        "VisualGlideSlopeIndicator",
        uuid: "papi",
        Doc.value("slopeAngle", "3"),
        Doc.value("minimumEyeHeightOverThreshold", "52", uom: "FT"),
        Doc.reference("runwayDirection", "urn:uuid:rdn09"),
        Doc.reference("runwayDirection", "urn:uuid:rdn27")
      )
    )
    let expected = VisualGlideSlope(
      angle: Measurement(value: 3, unit: .degrees),
      minimumEyeHeightOverThreshold: Measurement(value: 52, unit: .feet)
    )
    #expect(problems.isEmpty)
    #expect(directions.map(\.visualGlideSlope) == [expected, expected])
  }

  @Test
  func `reports an indicator whose runway direction is unresolved`() throws {
    let (_, problems) = try Self.directions(
      Doc.feature(
        "VisualGlideSlopeIndicator",
        uuid: "papi",
        Doc.value("slopeAngle", "3"),
        Doc.reference("runwayDirection", "#nowhere")
      )
    )
    #expect(
      problems == [
        .unresolved(feature: "VisualGlideSlopeIndicator", id: "papi", reference: "#nowhere")
      ]
    )
  }
}
