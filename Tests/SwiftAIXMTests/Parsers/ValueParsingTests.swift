import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `Length values` {
  @Test(arguments: [
    ("M", UnitLength.meters),
    ("FT", .feet),
    ("KM", .kilometers),
    ("NM", .nauticalMiles),
    ("MI", .miles),
    ("CM", .centimeters)
  ])
  func `reads each unit of measure`(_ unit: String, _ expected: UnitLength) {
    #expect(ValueParsing.length("12.5", unit: unit) == Measurement(value: 12.5, unit: expected))
  }

  @Test(
    arguments: [
      ("12", nil), ("12", ""), ("12", "YD"), ("twelve", "M"), (nil, "M")
    ] as [(String?, String?)]
  )
  func `rejects a value without a known unit or a number`(_ text: String?, _ unit: String?) {
    #expect(ValueParsing.length(text, unit: unit) == nil)
  }
}

@Suite
struct `Angle values` {
  @Test
  func `reads degrees`() {
    #expect(ValueParsing.degrees("-2.5") == Measurement(value: -2.5, unit: .degrees))
  }

  @Test(arguments: [nil, "", "3°"])
  func `rejects a value that is not a number`(_ text: String?) {
    #expect(ValueParsing.degrees(text) == nil)
  }
}

@Suite
struct `GML positions` {
  @Test
  func `reads latitude first in EPSG 4326`() {
    #expect(
      ValueParsing.positions("51.5 -0.25", srsName: "urn:ogc:def:crs:EPSG::4326")
        == [Location(latitudeDeg: 51.5, longitudeDeg: -0.25)]
    )
  }

  @Test
  func `reads latitude first when no reference system is named`() {
    #expect(
      ValueParsing.positions("51.5 -0.25", srsName: nil)
        == [Location(latitudeDeg: 51.5, longitudeDeg: -0.25)]
    )
  }

  @Test
  func `reads longitude first in CRS84`() {
    #expect(
      ValueParsing.positions("8.5 47.25", srsName: "urn:ogc:def:crs:OGC:1.3:CRS84")
        == [Location(latitudeDeg: 47.25, longitudeDeg: 8.5)]
    )
  }

  @Test
  func `reads every pair of a position list`() {
    #expect(
      ValueParsing.positions("47.0 8.0\n47.1 8.1  47.2 8.2", srsName: nil)
        == [
          Location(latitudeDeg: 47.0, longitudeDeg: 8.0),
          Location(latitudeDeg: 47.1, longitudeDeg: 8.1),
          Location(latitudeDeg: 47.2, longitudeDeg: 8.2)
        ]
    )
  }

  @Test(arguments: [nil, "", "47.0", "47.0 8.0 47.1", "47.0 north 8.0 8.1"])
  func `rejects a list that is not whole pairs of numbers`(_ text: String?) {
    #expect(ValueParsing.positions(text, srsName: nil) == nil)
  }
}

@Suite
struct `Hemisphere coordinates` {
  @Test(arguments: [
    ("47.26027778N", 47.26027778),
    ("011.34388889E", 11.34388889),
    ("33.5S", -33.5),
    ("4715.5N", 47.258_333_333_333_33),
    ("01120.5W", -11.341_666_666_666_67),
    ("471530N", 47.258_333_333_333_33),
    ("0112038.00W", -11.343_888_888_888_89)
  ])
  func `parses each notation`(_ text: String, _ expected: Double) throws {
    let value = try #require(ValueParsing.hemisphereCoordinate(text))
    #expect(abs(value - expected) < 1e-9)
  }

  @Test(arguments: ["", "47.5", "47.5X", "N", "-47.5N", "12345678N", "47.5.5N"])
  func `rejects malformed coordinates`(_ text: String) {
    #expect(ValueParsing.hemisphereCoordinate(text) == nil)
  }
}

@Suite
struct `GML time positions` {
  private static let midnight = Fixtures.effectiveDate

  @Test(arguments: [
    "2026-10-29T00:00:00Z",
    "2026-10-29T00:00:00.000Z",
    "2026-10-29T01:00:00+01:00",
    "2026-10-29T00:00:00",
    "2026-10-29T00:00:00.000",
    "2026-10-29"
  ])
  func `reads each form as the same instant`(_ text: String) {
    #expect(ValueParsing.date(text) == Self.midnight)
  }

  @Test
  func `keeps fractional seconds`() {
    #expect(ValueParsing.date("2026-10-29T00:00:00.5Z") == Self.midnight.addingTimeInterval(0.5))
  }

  @Test(arguments: [nil, "", "29/10/2026", "unknown"])
  func `rejects text that is not a time position`(_ text: String?) {
    #expect(ValueParsing.date(text) == nil)
  }
}
